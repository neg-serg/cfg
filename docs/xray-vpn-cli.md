# Xray VPN - CLI Usage

## Overview

Use the importer-based flow for the TUN VPN setup.

AmneziaVPN still keeps the source profile in `~/.config/AmneziaVPN.ORG/AmneziaVPN.conf`.
Import that profile into the runtime config at `~/.config/sing-box-tun/config.json`, then start `sing-box-tun`.

The TUN service reads the generated runtime config.
It does not read the Qt settings file directly.

## Paths

- Source config: `~/.config/AmneziaVPN.ORG/AmneziaVPN.conf`
- Generated runtime config: `~/.config/sing-box-tun/config.json`
- TUN service: `sing-box-tun.service`

## Usage

Refresh the runtime config after the AmneziaVPN profile changes:

```bash
scripts/amnezia-import-tun-config.sh import
```

Installed equivalent:

```bash
~/.local/bin/amnezia-import-tun-config import
```

Start the TUN service:

```bash
sudo systemctl start sing-box-tun
```

`sing-box-tun.service` runs `sing-box` with `~/.config/sing-box-tun/config.json`.

## Diagnostics

```bash
ls -l ~/.config/AmneziaVPN.ORG/AmneziaVPN.conf
ls -l ~/.config/sing-box-tun/config.json
sudo systemctl status sing-box-tun
journalctl -u sing-box-tun -b --no-pager
```

## Relation to AmneziaVPN

If the AmneziaVPN profile changes, rerun the importer command to regenerate `~/.config/sing-box-tun/config.json` before starting or restarting `sing-box-tun`.
