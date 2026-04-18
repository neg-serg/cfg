# Xray VPN - CLI Usage

## Overview

Use the importer-based flow for the VPN setup.

AmneziaVPN stores the active profile in `~/.config/AmneziaVPN.ORG/AmneziaVPN.conf`.
Import that profile into a runtime config at `~/.config/sing-box-tun/config.json`.

**Note:** Since AmneziaVPN 4.8.14.5, the stored config uses **Xray format** (VLESS Reality).
The generated `config.json` is an Xray configuration, not a sing‑box configuration.

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

### 2. Test the imported config (Xray SOCKS5)

```bash
scripts/test-vpn-connection.sh
```

This script starts Xray with the imported config, verifies connectivity through the SOCKS5 proxy (`127.0.0.1:10808`), then stops Xray.

Manual test:

```bash
# Start Xray in the background
~/.local/bin/xray run -config ~/.config/sing-box-tun/config.json &
XRAY_PID=$!

# Test with curl
curl --max-time 30 --socks5 127.0.0.1:10808 https://httpbin.org/ip

# Stop Xray
kill $XRAY_PID
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

- **“could not locate last_config in AmneziaVPN.conf”** – The profile may be empty or corrupted. Open AmneziaVPN GUI, ensure a server is added and connected, then try again.
- **“invalid serversList JSON”** – The importer expects a JSON‑encoded `serversList` field. If the format changed, update `scripts/amnezia-import-tun-config.sh`.
- **sing‑box reports “legacy inbound fields are deprecated”** – The Xray→sing‑box converter uses an outdated inbound syntax. Update the converter or manually adjust the generated sing‑box config.
- **TUN service not found** – Enable `vpn_split_router` in `states/data/hosts.yaml` and apply the `network.singbox` Salt state.
