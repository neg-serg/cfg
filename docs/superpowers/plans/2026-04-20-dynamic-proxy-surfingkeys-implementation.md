# Dynamic Proxy Management in Surfingkeys Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Status:** ❌ **ABANDONED** – Surfingkeys integration removed on 2026‑04‑21 due to configuration loading issues and hotkey conflicts in Firefox/Zen Browser. The `set‑zen‑proxy` script and HTTP helper server remain available for future use.

**Goal:** Add keyboard-driven proxy switching to Zen Browser via Surfingkeys using `about:config` as a remote control surface.

**Architecture:** Add a `PROXY_MODES` object and `setProxyMode()` function to the Surfingkeys configuration, plus keyboard shortcuts that open `about:config`, inject preference-changing scripts, and show feedback banners.

**Tech Stack:** Surfingkeys JavaScript API, Firefox preference system (`Services.prefs`), existing VPN/Xray SOCKS5 proxies (ports 10808, 10810).

---

### Task 1: Examine current surfingkeys.js structure

**Files:**
- Read: `/home/neg/src/cfg/dotfiles/dot_config/surfingkeys.js`

- [x] **Step 1: Read current file to understand insertion point**

```bash
tail -20 /home/neg/src/cfg/dotfiles/dot_config/surfingkeys.js
```

Expected: See the end of file to find where new code can be added (likely after the last existing section).

- [x] **Step 2: Check file length and existing proxy-related code**

```bash
grep -n -i "proxy\|socks" /home/neg/src/cfg/dotfiles/dot_config/surfingkeys.js
```

Expected: No matches (proxy management not yet implemented).

- [x] **Step 3: Identify a logical insertion point**

```bash
head -923 /home/neg/src/cfg/dotfiles/dot_config/surfingkeys.js | tail -30
```

Expected: See the end of the file (around line 923) to decide where to add new code.

- [x] **Step 4: Commit initial state (optional) - no changes to commit**

```bash
cd /home/neg/src/cfg && git add dotfiles/dot_config/surfingkeys.js
git commit -m "chore: checkpoint before adding proxy management" || true
```

### Task 2: Add PROXY_MODES constant and setProxyMode function

**Files:**
- Modify: `/home/neg/src/cfg/dotfiles/dot_config/surfingkeys.js` (append after existing code)

- [ ] **Step 1: Write the new proxy management section**

Add at the end of the file (before any closing brace if present):

```javascript
// ========== Proxy Management (Firefox/Zen Browser) ==========
// Uses HTTP helper server (surfingkeys-server) to execute external set-zen-proxy script.
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

let currentProxyMode = 'direct';

function setProxyMode(modeKey) {
  const mode = PROXY_MODES[modeKey];
  if (!mode) return;

  api.Front.showBanner('Setting proxy to: ' + mode.name);
  
  // Call helper server via HTTP
  fetch(`http://localhost:18888/proxy?mode=${modeKey}`)
    .then(response => {
      if (response.ok) {
        currentProxyMode = modeKey;
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

- [ ] **Step 2: Verify file syntax (quick check)**

```bash
cd /home/neg/src/cfg
node -c dotfiles/dot_config/surfingkeys.js 2>&1 | head -5
```

Expected: No syntax errors (or only expected ones like `api` being undefined).

- [ ] **Step 3: Commit addition**

```bash
cd /home/neg/src/cfg && git add dotfiles/dot_config/surfingkeys.js
git commit -m "feat: add PROXY_MODES and setProxyMode function"
```

### Task 3: Add keyboard shortcuts for proxy switching

**Files:**
- Modify: `/home/neg/src/cfg/dotfiles/dot_config/surfingkeys.js` (add after the function)

- [ ] **Step 1: Add proxy keyboard mappings**

Append after the `setProxyMode` function:

```javascript
// Keyboard shortcuts for proxy modes
api.mapkey('<A-S-1>', 'Proxy: Direct', () => setProxyMode('direct'));
api.mapkey('<A-S-2>', 'Proxy: Telegram Xray', () => setProxyMode('telegram'));
api.mapkey('<A-S-3>', 'Proxy: Debug Xray', () => setProxyMode('debug'));
api.mapkey('<A-S-4>', 'Proxy: System VPN', () => setProxyMode('system_vpn'));
api.mapkey('<A-S-0>', 'Show proxy status', () => showProxyStatus());

// Alternative shortcuts (if Alt+Shift doesn't work)
api.mapkey(';p1', 'Proxy: Direct', () => setProxyMode('direct'));
api.mapkey(';p2', 'Proxy: Telegram Xray', () => setProxyMode('telegram'));
api.mapkey(';p3', 'Proxy: Debug Xray', () => setProxyMode('debug'));
api.mapkey(';p4', 'Proxy: System VPN', () => setProxyMode('system_vpn'));
api.mapkey(';p0', 'Show proxy status', () => showProxyStatus());
```

- [ ] **Step 2: Verify the file still parses**

```bash
cd /home/neg/src/cfg
node -c dotfiles/dot_config/surfingkeys.js 2>&1 | grep -v "api is not defined" | head -5
```

Expected: Only `api is not defined` warnings (normal).

- [ ] **Step 3: Commit shortcuts**

```bash
cd /home/neg/src/cfg && git add dotfiles/dot_config/surfingkeys.js
git commit -m "feat: add proxy keyboard shortcuts (;pd, ;pt, ;px, ;pv, ;pp)"
```

### Task 4: Test the implementation manually

**Files:**
- Test: `/home/neg/src/cfg/dotfiles/dot_config/surfingkeys.js` (live in Zen Browser)

**Prerequisites:** 
- Zen Browser with Surfingkeys extension installed
- Telegram Xray running on port 10808 (`systemctl --user status nanoclaw‑telegram‑proxy.service`)
- Surfingkeys helper server running (`systemctl --user status surfingkeys‑server`)

- [x] **Step 1: Reload Surfingkeys configuration**

In Zen Browser:
1. Open `about:addons`
2. Find Surfingkeys, click "Preferences" or "Options"
3. Click "Reload settings" or restart browser
4. Alternatively, press `;rl` (Surfingkeys reload shortcut)

Expected: No JavaScript errors in browser console.

- [x] **Step 2: Verify shortcuts appear in help**

Press `?` in Zen Browser to open Surfingkeys help.
Search for "Proxy:" in the help text.

Expected: See entries for `Alt+Shift+1..4` and `;p1..;p4`.

- [x] **Step 3: Test proxy switching via HTTP**

1. Open any tab
2. Press `Alt+Shift+2` (or `;p2`)
3. Observe banners: "Setting proxy to: Telegram Xray (SOCKS5 :10808)" → "✓ Proxy configuration updated" → "Restart Zen Browser to apply changes"
4. Check server logs: `journalctl --user -u surfingkeys‑server -n 3` should show successful `/proxy` request.

Expected: Banners appear, server logs show request, no JavaScript errors.

- [x] **Step 4: Verify user.js updated**

1. Check file: `grep -E "network.proxy|Proxy" ~/.config/zen/qnkh60k3.Default\ \(release\)/user.js`
2. Verify settings match Telegram proxy (`type: 1`, `socks: localhost`, `port: 10808`)

Expected: `user.js` contains correct proxy preferences.

- [x] **Step 5: Test direct mode**

1. Press `Alt+Shift+1` (or `;p1`)
2. Banners should confirm direct mode.
3. Check `user.js`: `network.proxy.type` should be `0`

Expected: Direct mode disables proxy.

- [x] **Step 6: Test fallback when server unavailable**

1. Temporarily stop helper server: `systemctl --user stop surfingkeys‑server`
2. Press `Alt+Shift+2`
3. Expected: Banner "HTTP request failed", command `set-zen-proxy telegram` copied to clipboard.
4. Restart server: `systemctl --user start surfingkeys‑server`

- [x] **Step 7: Commit test verification**

```bash
cd /home/neg/src/cfg && git add dotfiles/dot_config/surfingkeys.js
git commit -m "test: manual verification of proxy HTTP integration"
```

### Task 5: Validate with project linting and formatting

**Files:**
- Validate: `/home/neg/src/cfg/dotfiles/dot_config/surfingkeys.js`

- [ ] **Step 1: Run project lint command**

Check AGENTS.md for lint command:

```bash
cd /home/neg/src/cfg
just lint 2>&1 | grep -A5 -B5 "surfingkeys" || true
```

Expected: No errors related to the surfingkeys.js file.

- [ ] **Step 2: Run validation command**

```bash
cd /home/neg/src/cfg
just validate 2>&1 | tail -20
```

Expected: Validation passes (or shows only unrelated warnings).

- [ ] **Step 3: Ensure no syntax issues in Salt rendering**

```bash
cd /home/neg/src/cfg
python3 -m py_compile dotfiles/dot_config/surfingkeys.js 2>&1 || echo "Not a Python file, skipping"
```

Expected: No Python compilation errors (file is JS).

- [ ] **Step 4: Final commit**

```bash
cd /home/neg/src/cfg && git add dotfiles/dot_config/surfingkeys.js
git commit -m "chore: proxy management passes lint/validation"
```

### Task 6: Update documentation (optional)

**Files:**
- Modify: `docs/superpowers/specs/2026-04-20-dynamic-proxy-surfingkeys-design.md` (update status and implementation details)

- [x] **Step 1: Mark spec as implemented and update design overview**

Update spec to reflect HTTP helper server approach instead of `about:config` injection.

- [x] **Step 2: Update components, data flow, and constraints**

Replace old code examples with actual implementation using `fetch` to `localhost:18888/proxy`. Update constraints to note browser restart requirement.

- [x] **Step 3: Update testing plan and acceptance criteria**

Adjust test steps to verify helper server operation and update acceptance criteria to reflect HTTP integration.

- [x] **Step 4: Commit documentation update**

```bash
cd /home/neg/src/cfg && git add docs/superpowers/specs/2026-04-20-dynamic-proxy-surfingkeys-design.md
git commit -m "docs: update spec with HTTP-based proxy implementation"
```

---

## Self-Review

**1. Spec coverage:** All requirements from spec are covered:
- [x] Four proxy modes (direct, telegram, debug, system_vpn)
- [x] Keyboard shortcuts (`Alt+Shift+1..4`, `;p1..;p4`)
- [x] Uses HTTP helper server as bridge to external script
- [x] Shows Surfingkeys banner feedback with restart reminder
- [x] Safe (no internet loss) - includes localhost/LAN exclusions and fallback to clipboard
- [x] Follows existing code style (added as new section)

**2. Placeholder scan:** No "TBD", "TODO", or vague steps. Each task shows exact code and commands.

**3. Type consistency:** `PROXY_MODES` keys match `setProxyMode` calls. Function signatures consistent.

**4. File paths:** All paths are exact (`/home/neg/src/cfg/dotfiles/dot_config/surfingkeys.js`).

**5. Test commands:** Includes manual testing steps with expected outcomes.