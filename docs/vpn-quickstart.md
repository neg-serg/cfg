# VPN via Command Line - Quick Start

## Check if VPN is running

VPN might already be running from a previous session:

```bash
curl --max-time 5 --socks5 127.0.0.1:10808 https://ifconfig.me 2>/dev/null && echo "VPN working" || echo "VPN not running"
```

If the command returns an IP address, skip to step 3.

## First-Time Setup

### 1. Import AmneziaVPN config

```bash
scripts/amnezia-import-tun-config.sh import
```

### 2. Start VPN (SOCKS5 proxy on port 10808)

```bash
~/.local/bin/xray run -config ~/.config/sing-box-tun/config.json &
```

### 3. Verify connectivity

```bash
curl --socks5 127.0.0.1:10808 https://ifconfig.me && echo
```

## Basic Usage

```bash
# Per-command
curl --socks5 127.0.0.1:10808 https://google.com

# Session-wide (all terminal commands in this shell)
export ALL_PROXY=socks5://127.0.0.1:10808
```

## Stop VPN

```bash
pkill -f "xray.*config.json"
```

## See also

[xray-vpn-cli.md](xray-vpn-cli.md) — comprehensive reference: SOCKS5 usage for all programs (curl, git, wget, pacman, apt, Python, Node.js), VPN status checks, TUN routing, hybrid scheme, full troubleshooting guide, and Salt deployment.
