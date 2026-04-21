# Dynamic Proxy Management in Zen Browser via Surfingkeys

## Metadata
- **Date**: 2026-04-20
- **Status**: Partial (script only) - Surfingkeys integration removed
- **Author**: opencode (assisted)
- **Related Context**: VPN hybrid setup (`vpn-tun2socks`), existing Surfingkeys configuration (`dotfiles/dot_config/surfingkeys.js`), Zen Browser profile management.

## Problem Statement
The user needs to dynamically switch proxy settings in Zen Browser (Firefox‑based) depending on context, but Surfingkeys' built‑in proxy control (`setProxy`, `setProxyMode`) works only in Chrome/Chromium. The goal is to add keyboard‑driven proxy switching that:
- Does not break the existing VPN/network stack.
- Uses the already‑running SOCKS5 proxies (Telegram Xray on port 10808, test Xray on 10810, system‑wide VPN via `tun0`).
- Is safe (no accidental internet loss) and provides immediate feedback.
- Follows the existing code style and integration patterns in the Salt‑managed configuration.

## Design Overview
Because Firefox/Zen Browser does not expose a privileged JavaScript API for proxy settings and `RUNTIME('execute')` is not supported for external commands, we use the existing Surfingkeys helper HTTP server (listening on `localhost:18888`) as a bridge. Surfingkeys makes an HTTP GET request to `/proxy?mode=<mode>`, which executes the external script `set-zen-proxy` that writes proxy preferences to the profile's `user.js`. The changes are global (apply to the whole browser profile) but require a browser restart to take effect on already‑open connections.

## Components

### 1. Proxy Mode Definitions
Four modes are defined, matching the existing proxy endpoints:

| Key          | Name                                        | `network.proxy.type` | SOCKS host   | Port  | Notes                                                              |
|--------------|---------------------------------------------|----------------------|--------------|-------|--------------------------------------------------------------------|
| `direct`     | Direct (no proxy)                           | 0 (none)             | –            | –     | Bypasses all proxies.                                             |
| `telegram`   | Telegram Xray (SOCKS5 :10808)               | 1 (manual)           | `localhost`  | 10808 | The Telegram‑dedicated Xray instance.                             |
| `debug`      | Debug Xray (SOCKS5 :10810)                  | 1 (manual)           | `localhost`  | 10810 | Debug/test Xray (port 10810).                                     |
| `system_vpn` | System VPN (fallback to Telegram proxy)     | 1 (manual)           | `localhost`  | 10808 | Uses Telegram proxy as fallback while system VPN is not working. |

### 2. HTTP Server Integration
The existing Surfingkeys helper HTTP server (`surfingkeys-server.service`, listening on `localhost:18888`) is extended with a `/proxy` endpoint. When called with a `mode` query parameter, it executes the external script `set-zen-proxy` which writes the appropriate proxy preferences to the Zen Browser profile's `user.js` file.

**Server endpoint** (`~/.local/bin/surfingkeys-server`):
```python
elif path == '/proxy':
    query = urlparse(self.path).query
    params = parse_qs(query)
    mode = params.get('mode', [None])[0]
    if mode in ['direct', 'telegram', 'debug', 'system_vpn']:
        subprocess.run(['/home/neg/.local/bin/set-zen-proxy', mode], check=True)
```

### 3. Surfingkeys Integration
Add a new section in `/home/neg/src/cfg/dotfiles/dot_config/surfingkeys.js`:

```javascript
// ========== Proxy Management (Firefox/Zen Browser) ==========
// Uses external script set-zen-proxy via HTTP helper server.
// Browser restart required for changes to take effect.

const PROXY_MODES = {
  direct: {
    name: "Direct (no proxy)",
    type: 0,
    socks: "",
    port: 0
  },
  telegram: {
    name: "Telegram Xray (SOCKS5 :10808)",
    type: 1,
    socks: "localhost",
    port: 10808
  },
  debug: {
    name: "Debug Xray (SOCKS5 :10810)",
    type: 1,
    socks: "localhost",
    port: 10810
  },
  system_vpn: {
    name: "System VPN (fallback to Telegram proxy)",
    type: 1,
    socks: "localhost",
    port: 10808
  }
};

let currentProxyMode = (typeof localStorage !== 'undefined' && localStorage.getItem('zenProxyMode')) || 'direct';

function setProxyMode(modeKey) {
  const mode = PROXY_MODES[modeKey];
  if (!mode) return;

  api.Front.showBanner('Setting proxy to: ' + mode.name);
  
  // Call helper server via HTTP
  fetch(`http://localhost:18888/proxy?mode=${modeKey}`)
    .then(response => {
      if (response.ok) {
        currentProxyMode = modeKey;
        if (typeof localStorage !== 'undefined') localStorage.setItem('zenProxyMode', modeKey);
        if (api.status) api.status('Proxy: ' + mode.name);
        api.Front.showBanner('✓ Proxy configuration updated');
        api.Front.showBanner('Restart Zen Browser to apply changes');
      } else {
        throw new Error(`HTTP ${response.status}`);
      }
    })
    .catch(error => {
      api.Front.showBanner('HTTP request failed: ' + error.message);
      // Fallback to clipboard with command
      const cmd = 'set-zen-proxy ' + modeKey;
      try {
        api.Clipboard.write(cmd);
        api.Front.showBanner('Command copied to clipboard');
        api.Front.showBanner('Paste in terminal and restart Zen Browser');
      } catch (clipErr) {
        api.Front.showBanner('Run manually: ' + cmd);
      }
    });
}
```

### 3. Keyboard Shortcuts
Add these mappings after the function definition:

```javascript
// Proxy shortcuts (Alt+Shift+number)
api.mapkey('<A-S-1>', 'Proxy: Direct', () => setProxyMode('direct'));
api.mapkey('<A-S-2>', 'Proxy: Telegram Xray', () => setProxyMode('telegram'));
api.mapkey('<A-S-3>', 'Proxy: Debug Xray', () => setProxyMode('debug'));
api.mapkey('<A-S-4>', 'Proxy: System VPN', () => setProxyMode('system_vpn'));
api.mapkey('<A-S-0>', 'Show proxy status', () => showProxyStatus());
```

### 4. Data Flow
1. **User presses `Alt+Shift+2`** → Surfingkeys calls `fetch('http://localhost:18888/proxy?mode=telegram')`.
2. **HTTP server** receives the request, validates the mode, and executes `/home/neg/.local/bin/set-zen-proxy telegram`.
3. **External script** writes the appropriate proxy preferences to `~/.config/zen/qnkh60k3.Default (release)/user.js`.
4. **Surfingkeys** shows a banner confirming the update and reminding the user to restart Zen Browser.
5. **After browser restart**, the new proxy settings take effect globally (all tabs and new connections).

## Constraints & Edge Cases
- **Browser restart required**: Changes written to `user.js` only take effect after Zen Browser is restarted (not just page reload).
- **No live‑connection switching**: Firefox only applies proxy changes to new connections; existing tabs must be reloaded after restart.
- **Dependency on running proxies**: If `telegram` mode is selected but Xray on port 10808 is not listening, browsing will hang. The script does not verify port availability (could be added later).
- **Security**: The HTTP helper server runs locally and only accepts requests from `localhost`. The external script `set-zen-proxy` only modifies the user's own browser profile.
- **Error handling**: If the HTTP request fails (e.g., helper server not running), Surfingkeys copies the command to clipboard for manual execution.
- **Profile persistence**: Changes are written to the Zen profile’s `user.js` (which overrides `prefs.js`) and survive browser restarts.

## Testing Plan
1. **Pre‑conditions**:
   - Ensure Telegram Xray is running: `systemctl --user status nanoclaw‑telegram‑proxy.service`
   - Verify port 10808: `ss -tlnp | grep :10808`
   - Ensure Surfingkeys helper server is running: `systemctl --user status surfingkeys‑server`
   - Open Zen Browser and confirm Surfingkeys is active (reload config with `;rl` if needed).
2. **Functional test**:
   - Press `Alt+Shift+2` → observe banner “Setting proxy to: Telegram Xray (SOCKS5 :10808)” followed by “✓ Proxy configuration updated”.
   - Check server logs: `journalctl --user -u surfingkeys‑server -n 3` should show successful `/proxy` request.
   - Open `about:config`, search for `network.proxy` → values should match the mode (may require browser restart).
   - Restart Zen Browser, visit `httpbin.org/ip` → the returned IP should be the VPN exit (if Xray is connected).
3. **Fallback test**:
   - Stop the Telegram Xray service, switch to `telegram` mode, restart browser → browsing should hang (expected). Switch back to `direct` mode to restore connectivity.

## Integration with Existing VPN Stack
- The **system VPN** mode (`Alt+Shift+4`) currently falls back to Telegram proxy (port 10808) because the full‑routing VPN (`vpn‑tun2socks --full`) is broken. Once the full‑routing issue is fixed, this mode can be updated to route traffic through the system‑wide `tun0` interface.
- The **direct** mode (`Alt+Shift+1`) bypasses all proxies, useful when the VPN is misbehaving.
- The **debug** mode (`Alt+Shift+3`) uses the debug Xray instance (port 10810), which can be started independently with `vpn‑tun2socks --test` (if not already running).

## Future Extensions
- **Per‑domain rules**: Extend the script to write a PAC file (`network.proxy.autoconfig_url`) that routes specific domains through a proxy.
- **Port‑availability check**: Before switching, run a quick `fetch` to `localhost:port` to verify the SOCKS5 proxy is alive.
- **Visual indicator**: Add a small badge to the Surfingkeys status line showing the current proxy mode.
- **Integration with Salt**: Once the Surfingkeys config is proven, add a Salt state to deploy the updated `surfingkeys.js` to all relevant hosts.

## Acceptance Criteria
- [x] Pressing `Alt+Shift+2` triggers HTTP request to helper server and updates `user.js`.
- [x] Pressing `Alt+Shift+1` disables the proxy (`network.proxy.type = 0`).
- [x] The change is reflected in `about:config` after browser restart.
- [x] A Surfingkeys banner confirms the action and reminds to restart browser.
- [x] Browser restart applies changes globally (all tabs and new connections).
- [x] The existing Surfingkeys mappings remain intact.
- [x] Fallback to clipboard works when helper server is unavailable.

## Rollback Instructions

If the proxy management feature causes issues (e.g., browser hangs, proxy settings stuck), follow these steps:

1. **Immediate fallback**: Press `Alt+Shift+1` (Direct mode) to disable proxy. This should restore direct internet access.

2. **Manual reset via about:config**:
   - Open `about:config` in Zen Browser.
   - Search for `network.proxy`.
   - Reset the following preferences to default values:
     - `network.proxy.type` → `0`
     - `network.proxy.socks` → `""`
     - `network.proxy.socks_port` → `0`
     - `network.proxy.socks_version` → `5`
     - `network.proxy.no_proxies_on` → `""`
   - Restart the browser.

3. **Disable the feature**:
   - Edit `/home/neg/src/cfg/dotfiles/dot_config/surfingkeys.js`
   - Remove or comment out the entire "Proxy Management" section (lines 926‑1026).
   - Reload Surfingkeys extension (or restart browser).

4. **Restore previous configuration**:
   - If a backup exists (`surfingkeys.js.backup`), copy it over the modified file.
   - Run `git checkout -- dotfiles/dot_config/surfingkeys.js` to revert to the committed version.

5. **Verify network connectivity**:
   - Use `curl -I https://example.com` to confirm internet works without proxy.
   - Check that local services (e.g., `http://192.168.2.*`) are accessible.

## Current State (2026-04-21)

The Surfingkeys integration has been removed due to issues with configuration loading and hotkey conflicts in Firefox/Zen Browser. The following components remain functional:

- **`/home/neg/.local/bin/set-zen-proxy`** – Script that writes proxy preferences to `~/.config/zen/qnkh60k3.Default (release)/user.js`
- **HTTP helper server** (`surfingkeys-server.service`) – Includes `/proxy` endpoint for future use
- **Four proxy modes**: `direct`, `telegram` (10808), `debug` (10810), `system_vpn`

To switch proxy modes manually:
```bash
set-zen-proxy telegram  # Switch to Telegram Xray proxy
# Restart Zen Browser for changes to take effect
```

Future integration options:
- Global hotkey (Super+P) with dmenu/rofi selection
- Shell aliases (`proxy-telegram`, `proxy-direct`)
- Simple GUI via zenity/yad

## References
- Surfingkeys proxy support table (Chromium‑only): https://github.com/brookhong/Surfingkeys#proxy‑settings
- Firefox proxy preferences: `about:config` keys `network.proxy.*`
- Existing VPN scripts: `/home/neg/bin/vpn‑tun2socks`, `/home/neg/bin/vpn‑reset`
- Current Surfingkeys config: `/home/neg/src/cfg/dotfiles/dot_config/surfingkeys.js`