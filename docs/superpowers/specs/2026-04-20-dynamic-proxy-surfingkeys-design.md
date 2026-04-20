# Dynamic Proxy Management in Zen Browser via Surfingkeys

## Metadata
- **Date**: 2026-04-20
- **Status**: Draft
- **Author**: opencode (assisted)
- **Related Context**: VPN hybrid setup (`vpn-tun2socks`), existing Surfingkeys configuration (`dotfiles/dot_config/surfingkeys.js`), Zen Browser profile management.

## Problem Statement
The user needs to dynamically switch proxy settings in Zen Browser (Firefox‑based) depending on context, but Surfingkeys' built‑in proxy control (`setProxy`, `setProxyMode`) works only in Chrome/Chromium. The goal is to add keyboard‑driven proxy switching that:
- Does not break the existing VPN/network stack.
- Uses the already‑running SOCKS5 proxies (Telegram Xray on port 10808, test Xray on 10810, system‑wide VPN via `tun0`).
- Is safe (no accidental internet loss) and provides immediate feedback.
- Follows the existing code style and integration patterns in the Salt‑managed configuration.

## Design Overview
Because Firefox/Zen Browser does not expose a privileged JavaScript API for proxy settings, we use `about:config` as a “remote control” surface: Surfingkeys opens `about:config` in a new tab, injects a script that changes the relevant `pref()` values, and notifies the user. The changes are global (apply to the whole browser profile) and require a page reload to take effect on already‑open connections.

## Components

### 1. Proxy Mode Definitions
Four modes are defined, matching the existing proxy endpoints:

| Key          | Name                                        | `network.proxy.type` | SOCKS host   | Port  | Notes                                                              |
|--------------|---------------------------------------------|----------------------|--------------|-------|--------------------------------------------------------------------|
| `direct`     | Direct (no proxy)                           | 0 (none)             | –            | –     | Bypasses all proxies.                                             |
| `telegram`   | Telegram Xray (SOCKS5 :10808)               | 1 (manual)           | `localhost`  | 10808 | The Telegram‑dedicated Xray instance.                             |
| `debug`      | Debug Xray (SOCKS5 :10810)                  | 1 (manual)           | `localhost`  | 10810 | Debug/test Xray (port 10810).                                     |
| `system_vpn` | System VPN (fallback to Telegram proxy)     | 1 (manual)           | `localhost`  | 10808 | Uses Telegram proxy as fallback while system VPN is not working. |

### 2. Surfingkeys Integration
Add a new section in `/home/neg/src/cfg/dotfiles/dot_config/surfingkeys.js`:

```javascript
// ========== Proxy Management (Firefox/Zen Browser) ==========
// Uses about:config as a “remote API” to change proxy prefs.

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
  test: {
    name: "Test Xray (SOCKS5 :10810)",
    type: 1,
    socks: "localhost",
    port: 10810
  },
  system: {
    name: "System VPN (auto‑detect)",
    type: 4,
    socks: "",
    port: 0
  }
};

function setProxyMode(modeKey) {
  const mode = PROXY_MODES[modeKey];
  if (!mode) return;

  // Open about:config in a new tab
  api.RUNTIME('openLink', {
    tab: { tabbed: true, active: true },
    url: 'about:config'
  });

  // Wait for page load, then inject script
  setTimeout(() => {
    api.Front.executeScript({
      code: `
        try {
          // network.proxy.type:
          // 0 = direct, 1 = manual, 2 = PAC, 4 = auto‑detect, 5 = system
          Services.prefs.setIntPref('network.proxy.type', ${mode.type});

          if (${mode.type} === 1) {
            // SOCKS5 proxy
            Services.prefs.setCharPref('network.proxy.socks', '${mode.socks}');
            Services.prefs.setIntPref('network.proxy.socks_port', ${mode.port});
            Services.prefs.setIntPref('network.proxy.socks_version', 5);

            // Do not proxy localhost and LAN
            Services.prefs.setBoolPref('network.proxy.allow_hijacking_localhost', true);
            Services.prefs.setCharPref('network.proxy.no_proxies_on', 'localhost, 127.0.0.1, 192.168.2.0/24');
          }

          // Force‑flush the preference change
          Services.obs.notifyObservers(null, 'nsPref:changed', 'network.proxy.type');

          window.dispatchEvent(new CustomEvent('ProxyChanged', {
            detail: { mode: '${modeKey}', name: '${mode.name}' }
          }));

          return { success: true, mode: '${mode.name}' };
        } catch (e) {
          return { success: false, error: e.toString() };
        }
      `
    }).then(result => {
      if (result && result[0] && result[0].success) {
        api.Front.showBanner(\`Proxy: \${result[0].mode}\`);
      } else {
        api.Front.showBanner(\`Proxy error: \${result ? result[0]?.error : 'unknown'}\`);
      }
    }).catch(e => {
      api.Front.showBanner(\`Failed to execute script: \${e.message}\`);
    });
  }, 1000);
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
1. **User presses `Alt+Shift+2`** → Surfingkeys opens `about:config` in a new background tab.
2. **After 1‑second delay** (page load), `api.Front.executeScript` injects the configuration script.
3. **Script runs in `about:config` context**:
   - Sets `network.proxy.type` and SOCKS5 details (if manual).
   - Adds exclusions for localhost and LAN (`192.168.2.0/24`).
   - Fires a `ProxyChanged` event (for potential future listeners).
4. **Result** is captured and shown as a Surfingkeys banner (e.g., “Proxy: Telegram Xray (SOCKS5 :10808)”).
5. **User reloads any active pages** to apply the new proxy settings (Firefox does not switch live connections).

## Constraints & Edge Cases
- **No live‑connection switching**: Firefox only applies proxy changes to new connections; existing tabs must be reloaded.
- **Dependency on running proxies**: If `telegram` mode is selected but Xray on port 10808 is not listening, browsing will hang. The script does not verify port availability (could be added later).
- **Security**: The injected script runs only on `about:config`, which already has full access to `Services.prefs`. No additional extension permissions are required.
- **Error handling**: If `executeScript` fails (e.g., because `about:config` is blocked by the browser), the banner shows the error; the user can manually edit `about:config`.
- **Profile persistence**: Changes are written to the Zen profile’s `prefs.js` and survive browser restarts.

## Testing Plan
1. **Pre‑conditions**:
   - Ensure Telegram Xray is running: `systemctl --user status nanoclaw‑telegram‑proxy.service`
   - Verify port 10808: `ss -tlnp | grep :10808`
   - Open Zen Browser and confirm Surfingkeys is active.
2. **Functional test**:
   - Press `Alt+Shift+2` → observe banner “Proxy: Telegram Xray (SOCKS5 :10808)”.
   - Open `about:config`, search for `network.proxy` → values should match the mode.
   - Visit `httpbin.org/ip` → the returned IP should be the VPN exit (if Xray is connected).
3. **Fallback test**:
   - Stop the Telegram Xray service, press `Alt+Shift+2` → browsing should hang (expected). Press `Alt+Shift+1` to revert to direct mode.

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
- [ ] Pressing `Alt+Shift+2` changes Zen Browser’s proxy to `localhost:10808` (SOCKS5).
- [ ] Pressing `Alt+Shift+1` disables the proxy (`network.proxy.type = 0`).
- [ ] The change is reflected in `about:config` without manual editing.
- [ ] A Surfingkeys banner confirms the action.
- [ ] No browser restart is required (only page reload).
- [ ] The existing Surfingkeys mappings remain intact.

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

## References
- Surfingkeys proxy support table (Chromium‑only): https://github.com/brookhong/Surfingkeys#proxy‑settings
- Firefox proxy preferences: `about:config` keys `network.proxy.*`
- Existing VPN scripts: `/home/neg/bin/vpn‑tun2socks`, `/home/neg/bin/vpn‑reset`
- Current Surfingkeys config: `/home/neg/src/cfg/dotfiles/dot_config/surfingkeys.js`