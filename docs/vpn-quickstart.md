# VPN via Command Line - Quick Start

## Quickest Way (SOCKS5 Proxy)

VPN might already be running! First check:

```bash
# Check if VPN is working
curl --socks5 127.0.0.1:10808 https://ifconfig.me && echo
```

If the command above shows an IP address (not an error), VPN is already working. Use it:

### Basic usage:
```bash
# Any site through VPN
curl --socks5 127.0.0.1:10808 https://google.com

# Or for the entire terminal session:
export ALL_PROXY=socks5://127.0.0.1:10808
export HTTP_PROXY=socks5://127.0.0.1:10808
export HTTPS_PROXY=socks5://127.0.0.1:10808

# Now all commands go through VPN
curl https://youtube.com      # through VPN
wget https://github.com       # through VPN
```

### For different programs:
```bash
# Git
git -c http.proxy=socks5://127.0.0.1:10808 clone https://github.com/...

# Wget
wget -e use_proxy=yes -e socks_proxy=127.0.0.1:10808 https://...

# Python/Node.js
export HTTP_PROXY=socks5://127.0.0.1:10808
export HTTPS_PROXY=socks5://127.0.0.1:10808
python script.py
```

## If VPN is not running

### 1. Import the config from AmneziaVPN:
```bash
scripts/amnezia-import-tun-config.sh import
```

### 2. Start VPN:
```bash
# Run in background
~/.local/bin/xray run -config ~/.config/sing-box-tun/config.json &

# Or run in the current terminal (Ctrl+C to stop)
~/.local/bin/xray run -config ~/.config/sing-box-tun/config.json
```

### 3. Verify:
```bash
curl --socks5 127.0.0.1:10808 https://ifconfig.me
```

## Checking VPN Status

Create a script `~/bin/vpn-status`:

```bash
#!/usr/bin/env bash
if ss -tlnp | grep -q ":10808"; then
    VPN_IP=$(curl --socks5 127.0.0.1:10808 --silent https://ifconfig.me 2>/dev/null || echo "no response")
    DIRECT_IP=$(curl --silent https://ifconfig.me 2>/dev/null || echo "no response")
    echo "SOCKS5 proxy: 127.0.0.1:10808"
    echo "VPN IP:       $VPN_IP"
    echo "Direct IP:    $DIRECT_IP"
    if [[ "$VPN_IP" != "$DIRECT_IP" ]] && [[ "$VPN_IP" != "no response" ]]; then
        echo "Status:       ✅ VPN WORKING (IP changed)"
    elif [[ "$VPN_IP" != "no response" ]]; then
        echo "Status:       ⚠️  VPN connected but IP unchanged"
    else
        echo "Status:       ❌ VPN not responding"
    fi
else
    echo "SOCKS5 proxy: Not listening on port 10808"
    echo "Status:       ❌ VPN not running"
fi
```

Usage: `vpn-status`

## Advanced Options

### Route All Traffic Through VPN (hybrid scheme)

For temporary routing of **all** system traffic (including GUI applications):

```bash
# Run with checks and auto-rollback
scripts/start-hybrid-vpn.sh

# The script will check:
# 1. Presence of Xray and sing-box binaries
# 2. Config file correctness
# 3. SOCKS5 proxy availability
# 4. TUN interface sb0 creation
# 5. Routing correctness

# On error at any stage, automatic rollback is performed
# On interrupt (Ctrl+C), all resources are cleaned up
```

#### Status check:
```bash
# Check if hybrid scheme is working
ip link show sb0 2>/dev/null && echo "TUN interface active" || echo "TUN inactive"

# Check routes through VPN
ip route show table 200 2>/dev/null | head -5

# Full status (if script is running)
systemctl --user status vpn-split-router 2>/dev/null || echo "Hybrid scheme running directly"
```

#### Rollback on issues:

If network issues persist after stopping the script:

```bash
# Full cleanup of VPN artifacts
sudo ip link delete sb0 2>/dev/null
sudo ip route flush table 200 2>/dev/null
sudo ip rule del pref 100 2>/dev/null
sudo ip rule del pref 200 2>/dev/null
pkill -f "xray.*config.json"
pkill -f "sing-box.*config"
```

### Check blocked site bypass
```bash
# Sites that are usually blocked
for site in "https://x.com" "https://t.me" "https://rutracker.org" "https://www.bbc.com/russian"; do
    echo -n "$site: "
    if timeout 5 curl --socks5 127.0.0.1:10808 --silent --head "$site" 2>/dev/null | head -1 | grep -q "HTTP"; then
        echo "✅ ACCESSIBLE"
    else
        echo "❌ not accessible"
    fi
done
```

## Common Issues

### "Connection refused" on port 10808
VPN is not running. Start it:
```bash
pkill -f "xray.*config.json" 2>/dev/null
~/.local/bin/xray run -config ~/.config/sing-box-tun/config.json &
```

### VPN connects but IP doesn't change
1. Update the config in AmneziaVPN GUI
2. Re-import: `scripts/amnezia-import-tun-config.sh import`
3. Try a different server in AmneziaVPN

### Some sites don't work through VPN
The site may be blocking VPN IPs. Try:
- Connect directly (without `--socks5`)
- Different VPN server
- Wait and retry

## Useful Commands

```bash
# Stop VPN
pkill -f "xray.*config.json"

# Check which Xray processes are running
pgrep -af xray

# View Xray logs (if running in background)
~/.local/bin/xray run -config ~/.config/sing-box-tun/config.json
```

## Summary

1. **Check** if VPN is already running: `curl --socks5 127.0.0.1:10808 https://ifconfig.me`
2. **If working** - use `--socks5 127.0.0.1:10808` or set environment variables
3. **If not working** - import the config and start Xray
4. **For automatic routing** - use the hybrid scheme

**Simplest way to make it permanent:**
```bash
echo 'export ALL_PROXY=socks5://127.0.0.1:10808' >> ~/.zshrc
echo 'export HTTP_PROXY=socks5://127.0.0.1:10808' >> ~/.zshrc
echo 'export HTTPS_PROXY=socks5://127.0.0.1:10808' >> ~/.zshrc
```
Now VPN will be used in all terminal sessions.
