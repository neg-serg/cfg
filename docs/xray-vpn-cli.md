# Xray VPN - CLI Usage

## Overview

Use the importer-based flow for the VPN setup.

AmneziaVPN stores the active profile in `~/.config/AmneziaVPN.ORG/AmneziaVPN.conf`.
Import that profile into a runtime config at `~/.config/sing-box-tun/config.json`.

**Note:** Since AmneziaVPN 4.8.14.5, the stored config uses **Xray format** (VLESS Reality).
The generated `config.json` is an Xray configuration, not a sing‑box configuration.

## Which option to choose?

- **For most users**: Use **SOCKS5 proxy** (port 10808) - simple, works with most CLI tools
- **For system-wide VPN**: Use **TUN interface** - routes all traffic automatically  
- **For AmneziaVPN XHTTP configs**: Use **Hybrid scheme** - Xray handles XHTTP, sing-box handles TUN

## Quick Start

### 1. Import AmneziaVPN config
```bash
scripts/amnezia-import-tun-config.sh import
```

### 2. Start VPN (SOCKS5 proxy on port 10808)
```bash
~/.local/bin/xray run -config ~/.config/sing-box-tun/config.json &
```

### 3. Use VPN immediately
```bash
# Test connection
curl --socks5 127.0.0.1:10808 https://httpbin.org/ip

# Browse through VPN
curl --socks5 127.0.0.1:10808 https://google.com

# Set proxy for current terminal session
export ALL_PROXY=socks5://127.0.0.1:10808
export HTTP_PROXY=socks5://127.0.0.1:10808
export HTTPS_PROXY=socks5://127.0.0.1:10808
```

You can:
- Test the imported config directly with Xray (SOCKS5 proxy)
- Convert it to sing‑box format for TUN routing (requires manual mapping)

## Paths

- Source config: `~/.config/AmneziaVPN.ORG/AmneziaVPN.conf`
- Generated runtime config: `~/.config/sing-box-tun/config.json` (Xray format)
- TUN service: `sing-box-tun.service` (requires sing‑box format)

## Usage

### 1. Import the current AmneziaVPN profile

```bash
scripts/amnezia-import-tun-config.sh import
```

Installed equivalent:

```bash
~/.local/bin/amnezia-import-tun-config import
```

The importer extracts the `last_config` field from the AmneziaVPN configuration.
If the import fails with “could not locate last_config”, check that the profile contains a valid server entry.

### 2. Simple SOCKS5 Proxy Usage (Recommended)

Once Xray is running with the AmneziaVPN config, it provides a SOCKS5 proxy on `127.0.0.1:10808`. This is the simplest way to access the internet without blockages.

#### Start the VPN:
```bash
# Start Xray in background
~/.local/bin/xray run -config ~/.config/sing-box-tun/config.json &
XRAY_PID=$!

# Or run in foreground (Ctrl+C to stop)
~/.local/bin/xray run -config ~/.config/sing-box-tun/config.json
```

#### Test connection:
```bash
# Quick test
curl --socks5 127.0.0.1:10808 https://httpbin.org/ip

# Check if VPN changes your IP
curl --socks5 127.0.0.1:10808 https://ifconfig.me && echo
curl https://ifconfig.me && echo
```

#### Use with different programs:

**curl/wget:**
```bash
curl --socks5 127.0.0.1:10808 https://google.com
wget -e use_proxy=yes -e socks_proxy=127.0.0.1:10808 https://example.com
```

**git:**
```bash
# For single command
git -c http.proxy=socks5://127.0.0.1:10808 clone https://github.com/user/repo.git

# For all git commands in current session
export GIT_PROXY=socks5://127.0.0.1:10808
```

**System-wide proxy for terminal session:**
```bash
# All curl/wget/git/etc will use VPN
export ALL_PROXY=socks5://127.0.0.1:10808
export HTTP_PROXY=socks5://127.0.0.1:10808
export HTTPS_PROXY=socks5://127.0.0.1:10808

# Now any command uses VPN automatically
curl https://google.com           # via VPN
wget https://example.com          # via VPN
```

**Package managers (temporary):**
```bash
# pacman (Arch)
sudo http_proxy=socks5://127.0.0.1:10888 https_proxy=socks5://127.0.0.1:10808 pacman -Syu

# apt (Debian/Ubuntu)
sudo http_proxy=socks5://127.0.0.1:10808 https_proxy=socks5://127.0.0.1:10808 apt update
```

**Python/Node.js applications:**
```bash
# Set environment variables before running
export HTTP_PROXY=socks5://127.0.0.1:10808
export HTTPS_PROXY=socks5://127.0.0.1:10808
python script.py
node app.js
```

#### Script to check VPN status:
```bash
#!/usr/bin/env bash
# Save as ~/bin/check-vpn
if curl --max-time 5 --socks5 127.0.0.1:10808 --silent https://ifconfig.me >/dev/null 2>&1; then
    VPN_IP=$(curl --socks5 127.0.0.1:10808 --silent https://ifconfig.me)
    DIRECT_IP=$(curl --silent https://ifconfig.me)
    echo "✅ VPN is working: $VPN_IP (direct: $DIRECT_IP)"
    if [[ "$VPN_IP" != "$DIRECT_IP" ]]; then
        echo "🎉 IP changed - bypassing blocking!"
    fi
else
    echo "❌ VPN is not working"
fi
```

### 2.5 Check if VPN is already running

Often Xray may already be running (e.g., from AmneziaVPN or previous session). Check before starting:

```bash
# Check if port 10808 is listening
ss -tlnp | grep :10808

# Check Xray processes
pgrep -af xray

# Quick connectivity test
curl --max-time 5 --socks5 127.0.0.1:10808 https://ifconfig.me 2>/dev/null && echo "✅ VPN already working" || echo "❌ VPN not responding"

# Full status check script
if ss -tlnp | grep -q ":10808"; then
    VPN_IP=$(curl --socks5 127.0.0.1:10808 --silent https://ifconfig.me 2>/dev/null || echo "no response")
    DIRECT_IP=$(curl --silent https://ifconfig.me 2>/dev/null || echo "no response")
    echo "SOCKS5 proxy: 127.0.0.1:10808"
    echo "VPN IP:       $VPN_IP"
    echo "Direct IP:    $DIRECT_IP"
    if [[ "$VPN_IP" != "$DIRECT_IP" ]] && [[ "$VPN_IP" != "no response" ]]; then
        echo "Status:       ✅ VPN ACTIVE (IP changed)"
    elif [[ "$VPN_IP" != "no response" ]]; then
        echo "Status:       ⚠️  VPN connected but IP unchanged"
    else
        echo "Status:       ❌ VPN not working"
    fi
else
    echo "SOCKS5 proxy: Not listening on 127.0.0.1:10808"
    echo "Status:       ❌ VPN not running"
fi
```

If VPN is already running, you can use it immediately:
```bash
export ALL_PROXY=socks5://127.0.0.1:10808
curl https://google.com
```

### 3. TUN routing (sing‑box)

To use the imported config with `sing-box-tun.service`, you must convert it to sing‑box format.

```bash
scripts/xray-to-singbox.py ~/.config/sing-box-tun/config.json ~/.config/sing-box-tun/config-singbox.json
```

**Note:** The converter is experimental and may produce invalid sing‑box configs due to API changes.
Check the result with:

```bash
sing-box check -c ~/.config/sing-box-tun/config-singbox.json
```

If the check passes, enable the TUN service:

## Zero-config router workflow

When `features.network.vpn_split_router` is enabled, use the helper to reconcile routing state and inspect decisions:

```bash
~/.local/bin/vpn-split-router recheck
~/.local/bin/vpn-split-router status
~/.local/bin/vpn-split-router list
```

Reconciliation also runs automatically via the user `systemd` units `vpn-split-router.timer` and `vpn-split-router.service`.

```bash
systemctl --user status vpn-split-router.timer vpn-split-router.service
```

Temporary state edit escape hatches:

```bash
~/.local/bin/vpn-split-router mark-vpn claude.ai
~/.local/bin/vpn-split-router mark-direct claude.ai
~/.local/bin/vpn-split-router forget claude.ai
```

`mark-vpn` and `mark-direct` only adjust the current router state until later reconciliation updates it.
`forget` only removes the current state entry; seed domains can reappear on a later `recheck` or timer run, while observed-only domains return only if an external producer observes them again or you add them back manually.

Start the TUN service:

```bash
sudo systemctl start sing-box-tun
```

## Diagnostics

```bash
# Source config
ls -l ~/.config/AmneziaVPN.ORG/AmneziaVPN.conf

# Imported runtime config
ls -l ~/.config/sing-box-tun/config.json

# Xray test
~/.local/bin/xray run -test -config ~/.config/sing-box-tun/config.json

# Service status (if sing‑box config is ready)
sudo systemctl status sing-box-tun
journalctl -u sing-box-tun -b --no-pager

# Quick VPN status check
scripts/check-vpn-status.sh

# Manual status check
if ss -tlnp | grep -q ":10808"; then
    echo "SOCKS5 proxy is listening on 127.0.0.1:10808"
    curl --socks5 127.0.0.1:10808 https://ifconfig.me 2>/dev/null && echo "VPN responsive" || echo "VPN not responding"
else
    echo "SOCKS5 proxy NOT listening"
fi
```

## Hybrid Scheme (Xray + sing-box TUN)

For AmneziaVPN configurations using XHTTP transport (Xray-specific), direct conversion to sing-box may fail because sing-box doesn't support XHTTP. A hybrid approach works:

1. **Xray** runs the original AmneziaVPN config with XHTTP+REALITY, providing SOCKS5 proxy on port 10808.
2. **sing-box** creates a TUN interface and routes traffic through the Xray SOCKS5 proxy.

**Steps:**

```bash
# Start hybrid VPN
scripts/start-hybrid-vpn.sh

# Or manually:
scripts/start-hybrid-vpn.sh ~/.config/sing-box-tun/config.json ~/.config/sing-box-tun/config-singbox-hybrid-final.json
```

**Configuration files:**

- Original Xray config: `~/.config/sing-box-tun/config.json`
- Hybrid sing-box config: `~/.config/sing-box-tun/config-singbox-hybrid-final.json`
- Converter script: `scripts/xray-to-singbox.py` (updated with correct TUN address syntax)

**TUN Configuration for sing-box 1.13+:**

Sing-box 1.12.0 removed legacy `inet4_address`/`inet6_address` fields. Use the unified `address` field:

```json
{
  "type": "tun",
  "tag": "tun-in",
  "interface_name": "sb0",
  "address": ["172.19.0.1/30", "fd00::1/126"],
  "mtu": 1500,
  "stack": "mixed",
  "auto_route": true,
  "strict_route": false,
  "endpoint_independent_nat": true
}
```

**Testing:**

The hybrid scheme provides:
- TUN interface `sb0` with automatic routing
- Split routing: private IPs go direct, external traffic goes through VPN
- DNS via local resolver (223.5.5.5) with fallback to TLS (1.1.1.1)

Test with `scripts/test-hybrid-routing.sh`.

## Relation to AmneziaVPN

If the AmneziaVPN profile changes, rerun the importer command to regenerate `~/.config/sing-box-tun/config.json` before starting or restarting any VPN client.

## Troubleshooting

### SOCKS5 Proxy Issues

- **"Connection refused" on port 10808** – Xray is not running. Start it with:
  ```bash
  ~/.local/bin/xray run -config ~/.config/sing-box-tun/config.json &
  ```

- **"curl: (7) Couldn't connect to server"** – Check if port 10808 is listening:
  ```bash
  ss -tlnp | grep :10808
  ```
  If not, Xray may have crashed. Check logs:
  ```bash
  ~/.local/bin/xray run -config ~/.config/sing-box-tun/config.json
  ```

- **VPN connects but IP doesn't change** – The VPN server might be blocked. Try:
  1. Update AmneziaVPN config (re-import)
  2. Try different server in AmneziaVPN GUI
  3. Check if direct connection works: `curl https://ifconfig.me`

- **"curl: (56) Recv failure: Connection reset by peer"** – The VPN server may be overloaded or blocked. Wait and retry.

### Import Issues

- **"could not locate last_config in AmneziaVPN.conf"** – The profile may be empty or corrupted. Open AmneziaVPN GUI, ensure a server is added and connected, then try again.
- **"invalid serversList JSON"** – The importer expects a JSON‑encoded `serversList` field. If the format changed, update `scripts/amnezia-import-tun-config.sh`.

### TUN/Sing-box Issues

- **sing‑box reports "legacy inbound fields are deprecated"** – The Xray→sing‑box converter uses an outdated inbound syntax. Update the converter or manually adjust the generated sing‑box config.
- **TUN service not found** – Enable `vpn_split_router` in `states/data/hosts.yaml` and apply the `network.singbox` Salt state.
- **"missing interface address" in sing-box** – Update TUN config to use `address` field instead of deprecated `inet4_address`/`inet6_address`.

### General

- **Slow speeds through VPN** – Normal due to encryption and distance. Try:
  - Different VPN server
  - Closer server location
  - SOCKS5 instead of TUN (less overhead)

- **Some sites don't work through VPN** – The site may block VPN IPs. Try:
  - Direct connection for that site
  - Different VPN server
  - Wait and retry later

## Automated Deployment via Salt

For automatic installation and configuration of the hybrid VPN scheme (Xray + sing-box TUN), use Salt states.

### Enabling Hybrid VPN

1. **Enable flags in host configuration** (`states/data/hosts.yaml`):
   ```yaml
   features:
     network:
       vpn_hybrid: true
       xray: true
       singbox: true
   ```

2. **Apply Salt states**:
   ```bash
   sudo salt-call --local state.apply network,services
   ```

   Or use the helper script:
   ```bash
   scripts/enable-vpn-hybrid.sh --enable-flags --apply
   ```

3. **Import AmneziaVPN configuration** (if not already done):
   ```bash
   amnezia-import-tun-config import
   ```

4. **Start services**:
   ```bash
   sudo systemctl start xray
   sudo systemctl start sing-box-tun-hybrid
   ```

### What Gets Installed

- **Xray**: Installed via AUR (package `xray`), configuration copied from `~/.config/sing-box-tun/config.json` to `/etc/xray/config.json`
- **Sing-box**: Installed via pacman (package `sing-box-bin`), capabilities `cap_net_admin,cap_net_raw,cap_net_bind_service`
- **Hybrid sing-box config**: `~/.config/sing-box-tun/hybrid-config.json` (TUN + SOCKS outbound to localhost:10808)
- **Systemd units**:
  - `xray.service` (uses config from /etc/xray/config.json)
  - `sing-box-tun-hybrid.service` (depends on xray.service, creates TUN interface sb0)

### Manual Start Without Systemd

```bash
# Start Xray
xray run -config ~/.config/sing-box-tun/config.json &

# Start sing-box with hybrid config
sing-box run -c ~/.config/sing-box-tun/hybrid-config.json
```

### Status Check

```bash
# Check service status
sudo systemctl status xray sing-box-tun-hybrid

# Check VPN connection via SOCKS5
curl --socks5 127.0.0.1:10808 https://ipinfo.io/json

# Check routing via TUN
ping -c 1 1.1.1.1
```

### Disabling Hybrid VPN

1. Stop services:
   ```bash
   sudo systemctl stop xray sing-box-tun-hybrid
   ```

2. Disable flags in `hosts.yaml`:
   ```yaml
   features:
     network:
       vpn_hybrid: false
       xray: false
       singbox: false
   ```

3. Apply Salt states to remove configuration:
   ```bash
   sudo salt-call --local state.apply network,services
   ```
