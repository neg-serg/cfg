# SonoBus Setup

Peer-to-peer low-latency audio streaming between devices. Installed from AUR (`sonobus`), runs as a standalone GTK application with VST3/LV2 plugin support.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│  SonoBus (standalone)                                   │
│  ┌──────────┐    ┌──────────┐    ┌───────────────────┐  │
│  │ Input    │    │ Effects  │    │ AOO Protocol      │  │
│  │ Mixer    │───→│ (EQ,     │───→│ (Opus / PCM over  │──→ P2P peers
│  │          │    │  Gate,   │    │  UDP)             │  │
│  └──────────┘    │  Reverb) │    └───────────────────┘  │
│                  └──────────┘              ▲             │
│  ┌──────────┐    ┌──────────┐              │             │
│  │ Recorder │←───│ Output   │←─────────────┘             │
│  │ (multi-  │    │ Mixer    │                             │
│  │  track)  │    └──────────┘                             │
└─────────────────────────────────────────────────────────┘
         │
         │ PipeWire / ALSA
         ▼
  RME HDSPe AIO Pro / USB Audio / HDMI
```

## Components

| Component | Package | Version | Source |
|---|---|---|---|
| SonoBus (standalone app) | `sonobus` (AUR) | 1.7.2 | AUR |
| SonoBus VST3 plugin | bundled | 1.7.2 | AUR build |
| SonoBus LV2 plugin | bundled | 1.7.2 | AUR build |
| SonoBus Instrument VST3 | bundled | 1.7.2 | AUR build |
| JUCE framework | vendored | bundled | upstream |
| AOO (Audio Over OSC) | vendored | bundled | upstream |

## Quick Start

### 1. Launch GUI

```bash
sonobus
```

Or from the application menu (desktop entry installed).

### 2. Connect to a group

In the GUI:
1. Enter a **Group Name** (shared secret — anyone with the same name joins)
2. Optionally set a **Group Password**
3. Set your **Display Name**
4. Click **Connect**

### 3. CLI launch (pre-configured)

```bash
# Connect to a group directly from command line
sonobus --group "my-session" --username "neg"

# With password and custom server
sonobus --group "my-session" --username "neg" \
  --group-password "secret" \
  --connectionserver "myserver.example.com"

# Headless (no GUI, for servers/automation)
sonobus --headless --group "my-session" --username "neg"
```

### 4. Save/Load setup presets

In the GUI: **Options → Save Setup** creates a `.setup` file with all device selections, mixer settings, and options. Load it later with:

```bash
sonobus --load-setup ~/music/sonobus/my-preset.setup
```

## Command-Line Options

| Flag | Description |
|---|---|
| `--group <name>` | Group name to connect to |
| `--username <name>` | Display name |
| `--group-password <pw>` | Group password (optional) |
| `--connectionserver <addr[:port]>` | Custom AOO server |
| `--load-setup <file>` | Load saved preset |
| `--headless` | No GUI mode |
| `--version` | Print version |
| `--help` | Print usage |

## Audio Device Integration

SonoBus uses PipeWire (via ALSA/JACK compatibility) on this system. Available devices:

| Device | Role | Notes |
|---|---|---|
| RME HDSPe AIO Pro | Primary I/O | 8 channels, managed by PipeWire |
| USB Audio | Secondary I/O | Generic USB audio interface |
| Navi 48 HDMI/DP | Output only | GPU audio over DisplayPort |

To route SonoBus through specific PipeWire nodes, use `pw-cli` or `qpwgraph` after SonoBus creates its audio ports.

## Connecting from Other Devices

| Platform | How to get it |
|---|---|
| **iOS** | App Store — search "SonoBus" |
| **Android** | Google Play / F-Droid — search "SonoBus" |
| **macOS** | Download from [sonobus.net](https://sonobus.net) |
| **Windows** | Download from [sonobus.net](https://sonobus.net) |
| **Linux (other)** | Build from source or AUR |
| **DAW (any)** | Use bundled VST3/LV2 plugin |

All devices join the same group by entering the same group name. No central server required — peers connect directly to each other.

## Encoding Options

| Mode | Quality | Bandwidth | Use case |
|---|---|---|---|
| PCM (uncompressed) | Lossless | ~1.4 Mbps (stereo 44.1kHz) | LAN, studio quality |
| Opus (high) | Near-lossless | ~128-256 kbps | Good internet |
| Opus (medium) | Good | ~64-128 kbps | Average internet |
| Opus (low) | Acceptable | ~32-64 kbps | Poor connectivity |

## File Locations

| Path | Purpose |
|---|---|
| `/usr/bin/sonobus` | Standalone binary |
| `/usr/share/applications/sonobus.desktop` | Desktop entry |
| `~/.config/SonoBus/` | User settings, presets |
| VST3: `/usr/lib/vst3/SonoBus.vst3/` | VST3 plugin |
| VST3: `/usr/lib/vst3/SonoBusInstrument.vst3/` | VST3 instrument plugin |
| LV2: `/usr/lib/lv2/SonoBus.lv2/` | LV2 plugin |

## Troubleshooting

### No audio devices in SonoBus

SonoBus uses ALSA directly. Check that ALSA devices are available:

```bash
aplay -l   # list playback devices
arecord -l # list capture devices
```

If devices are missing, verify PipeWire is running:

```bash
systemctl --user status pipewire wireplumber
```

### High latency

1. Switch encoding from PCM to Opus (lower bandwidth = less jitter)
2. Increase the jitter buffer slightly in SonoBus settings
3. Check network: `ping <peer_ip>` — should be <5ms on LAN
4. For LAN sessions, PCM is usually fine; for internet, use Opus

### Can't connect to group

1. Verify both peers use the **exact same** group name (case-sensitive)
2. Check firewall — SonoBus needs UDP ports open (dynamic range)
3. If behind NAT, the public AOO server helps with discovery but P2P still needs reachable IPs
4. Try a custom `--connectionserver` if the default server is unreachable

### Headless mode exits immediately

Headless mode requires `--group` to be specified. Without it, SonoBus prints an error and exits (exit code 0).
