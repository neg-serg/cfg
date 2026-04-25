# VPN Browser Integration Guide

This guide explains how to configure your browser to work with the hybrid VPN system (Xray + sing-box TUN) for accessing blocked RKN domains.

## Overview

The system consists of:
1. **Xray**: Handles XHTTP+REALITY transport
2. **sing-box**: Creates TUN interface (`sb0`) for VPN routing
3. **RKN Domains Fetcher**: Automatically downloads and updates lists of blocked domains
4. **VPN Split Router**: Dynamically detects blocked domains and routes them through VPN

## Quick Start

### 1. Start the VPN System

```bash
# Start hybrid VPN
sudo /home/neg/src/cfg/scripts/start-hybrid-vpn.sh

# Or use manual TUN setup (if auto_route fails)
sudo /home/neg/src/cfg/scripts/manual-tun-routes.sh start
```

### 2. Configure Browser Proxy

#### Zen Browser (Recommended)

```bash
# Use the helper script
/home/neg/src/cfg/scripts/zen-vpn.sh enable
```

Or manually:
1. Open Zen browser
2. Go to `about:preferences#general`
3. Scroll to "Network Settings" → "Settings..."
4. Select "Manual proxy configuration"
5. Configure:
   - SOCKS Host: `127.0.0.1`
   - Port: `10808`
   - Check "Proxy DNS when using SOCKS v5"
6. Click OK

#### Other Browsers

- **Firefox/Floorp**: Same as Zen browser
- **Chromium-based**: Use system proxy or extension
- **Command line**: Set `ALL_PROXY=socks5://127.0.0.1:10808`

### 3. Test the Connection

```bash
# Test VPN connectivity
/home/neg/src/cfg/scripts/test-browser-vpn.sh

# Test specific blocked site
curl --socks5 127.0.0.1:10808 https://twitter.com
```

## RKN Domains System

### Automatic Updates

The system automatically downloads and updates RKN blocked domains:

```bash
# Manual update
python3 /home/neg/src/cfg/scripts/rkn-domains-fetcher.py fetch --force --integrate

# Check status
python3 /home/neg/src/cfg/scripts/rkn-domains-fetcher.py status
```

### Systemd Services

Automatic updates are handled by systemd timers:

```bash
# Enable automatic updates
systemctl --user enable --now rkn-domains-fetcher.timer

# Check timer status
systemctl --user list-timers | grep rkn-domains

# Manual run
systemctl --user start rkn-domains-fetcher.service
```

### Integration with VPN Split Router

The system integrates with `vpn-split-router` to dynamically detect blocked domains:

```bash
# Check integration status
python3 /home/neg/src/cfg/scripts/vpn-split-router-integration.py

# Start VPN split router daemon
python3 /home/neg/src/cfg/scripts/vpn_split_router.py --daemon
```

## Advanced Configuration

### Custom sing-box Config with RKN Domains

Generate a sing-box config that includes RKN domains:

```bash
# Generate config with RKN domains
python3 /home/neg/src/cfg/scripts/singbox-with-rkn-domains.py --max-domains 1000

# Apply the config
cp ~/.config/sing-box-tun/config-with-rkn.json ~/.config/sing-box-tun/config.json
sudo pkill sing-box && sudo /home/neg/src/cfg/scripts/manual-tun-routes.sh start
```

### Manual TUN Routing

If automatic routing fails, use manual setup:

```bash
# Start manual routing
sudo /home/neg/src/cfg/scripts/manual-tun-routes.sh start

# Stop manual routing
sudo /home/neg/src/cfg/scripts/manual-tun-routes.sh stop

# Check routing tables
ip route show table vpn-tun
```

### Custom Domain Lists

Edit the configuration to customize domain handling:

```bash
# Edit RKN domains fetcher config
vim ~/.config/rkn-domains-fetcher/config.yaml

# Edit VPN split router config
vim ~/.config/vpn-split-router/config.yaml
```

Example configuration (`~/.config/rkn-domains-fetcher/config.yaml`):

```yaml
settings:
  update_interval_hours: 6
  max_domains: 50000
  fallback_retry_delay_seconds: 3

sources:
  primary: "https://raw.githubusercontent.com/EikeiDev/domains/main/domains.lst"
  backups:
    - "https://github.com/zapret-info/z-i/raw/master/dump.csv"
    - "https://reestr.rublacklist.net/api/v3/domains/"

integration:
  vpn_split_router:
    enabled: true
    auto_mark_vpn: true
    categories:
      ai_services: true
      social_media: true
      video: true
      vpn_proxy: false
```

## Troubleshooting

### Common Issues

1. **TUN interface not created**
   ```bash
   # Check if sing-box is running
   ps aux | grep sing-box
   
   # Check interface
   ip link show sb0
   
   # Restart with manual setup
   sudo pkill sing-box
   sudo /home/neg/src/cfg/scripts/manual-tun-routes.sh start
   ```

2. **Browser not using proxy**
   ```bash
   # Test proxy directly
   curl --socks5 127.0.0.1:10808 https://httpbin.org/ip
   
   # Check browser proxy settings
   /home/neg/src/cfg/scripts/test-browser-vpn.sh
   ```

3. **RKN domains not updating**
   ```bash
   # Check systemd service
   systemctl --user status rkn-domains-fetcher.service
   
   # Check logs
   journalctl --user -u rkn-domains-fetcher.service -f
   
   # Manual update with debug
   python3 /home/neg/src/cfg/scripts/rkn-domains-fetcher.py fetch --force -v
   ```

4. **VPN connection slow**
   ```bash
   # Test connection speed
   /home/neg/src/cfg/scripts/test-vpn-connection.sh
   
   # Check Xray logs
   tail -f ~/.config/xray/access.log
   ```

### Logs and Monitoring

```bash
# Sing-box logs
sudo journalctl -u sing-box-tun.service -f

# Xray logs
tail -f ~/.config/xray/access.log

# RKN domains fetcher logs
journalctl --user -u rkn-domains-fetcher.service -f

# VPN split router logs
python3 /home/neg/src/cfg/scripts/vpn_split_router.py --debug
```

## Maintenance

### Regular Updates

```bash
# Update all components
just update-vpn-system

# Or manually:
# 1. Update RKN domains
systemctl --user start rkn-domains-fetcher.service

# 2. Restart VPN services
sudo systemctl restart sing-box-tun
systemctl --user restart vpn-split-router

# 3. Verify everything works
/home/neg/src/cfg/scripts/test-browser-vpn.sh
```

### Backup and Restore

```bash
# Backup configurations
cp -r ~/.config/rkn-domains-fetcher ~/backup/
cp -r ~/.config/vpn-split-router ~/backup/
cp ~/.config/sing-box-tun/config.json ~/backup/

# Restore
cp -r ~/backup/rkn-domains-fetcher ~/.config/
cp -r ~/backup/vpn-split-router ~/.config/
cp ~/backup/config.json ~/.config/sing-box-tun/
```

## Security Considerations

1. **Proxy authentication**: The SOCKS5 proxy runs on localhost without authentication
2. **Domain filtering**: Only RKN-blocked domains are routed through VPN
3. **Automatic updates**: System updates domains every 6 hours
4. **Fallback sources**: Multiple backup sources in case primary fails
5. **Encryption**: All VPN traffic is encrypted via Xray+REALITY

## Support

For issues or questions:
1. Check logs: `journalctl --user -u rkn-domains-fetcher.service`
2. Test connectivity: `/home/neg/src/cfg/scripts/test-browser-vpn.sh`
3. Manual debug: Run components with `-v` flag
4. Check system status: `systemctl --user list-units | grep -E "(rkn|vpn|sing)"`

## Related Documentation

- VPN Quick Start (docs/vpn-quickstart.ru.md, Russian only)
- Hybrid VPN Architecture
- [Salt States for VPN](../states/README.md)
- [RKN Domains Fetcher Source Code](../scripts/rkn-domains-fetcher.py)