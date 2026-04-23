# HDSPe Post-Install: PipeWire config & verification

## Prerequisites

- snd-hdspe kernel module loaded (check: `lsmod | grep hdspe`)
- hdspeconf utility in PATH (`~/bin/hdspeconf`)

---

## Task 1: Verify HDSPe hardware detection

```bash
# 1. PCI device + driver
lspci -k | grep -iA 3 hdspe

# 2. Kernel messages
dmesg | grep -i hdspe

# 3. ALSA devices
aplay -l
arecord -l

# 4. PipeWire nodes
pw-cli list-objects Node | grep -i hdspe

# 5. hdspeconf can connect
~/bin/hdspeconf -l
```

Expected: card appears in lspci, ALSA, and PipeWire. hdspeconf shows the card.

---

## Task 2: Determine HDSPe model & capabilities

Run `lspci -v -s $(lspci -d 10ee: | cut -d' ' -f1)` to get the exact model.

Model-specific notes:
- HDSPe AES: 2x AES/EBU (4 channels)
- HDSPe MADI: 64 channels MADI
- HDSPe RayDAT: up to 36 channels (ADAT + AES + SPDIF)
- HDSPe AIO: analog + ADAT

---

## Task 3: PipeWire config for HDSPe

Investigate if any PipeWire config is needed:

1. **Default sink** — update `wireplumber.conf.d/10-default-volume.conf` if needed
2. **Profile / channel routing** — the HDSPe may expose multiple ALSA devices (hw:X,0 for playback, hw:X,1 for recording, etc.)
3. **Named nodes** — consider udev rules or WirePlumber policy to name the card's nodes consistently
4. **Sample rate / format** — if hdspeconf configures the card, PW should follow

Create a minimal config if needed (model-dependent).

---

## Task 4: Audio playback test

```bash
# Test with speaker-test (adjust -c to match channel count)
speaker-test -D hw:HDSPe -c 8 -t sine -f 440

# Or test through PipeWire
pw-play /usr/share/sounds/alsa/Front_Center.wav
```

---

## Task 5: Cleanup old ADI-2 artifacts (system-level)

From the previous session these were done:
- `snd-hdspe` DKMS module installed + signed + loaded
- `snd-hdspm` blacklisted in `/usr/lib/modprobe.d/hdspe.conf`
- `hdspeconf` + `dialog-warning.png` in `~/bin/`
- All repo files removed and committed

Check if any ADI-2 artifacts remain outside the repo:
- `~/.local/bin/sink-switch` — should be gone (was in repo)
- `/usr/local/bin/rme-usb-trigger` — should be gone (was deployed by Salt)
- Any PW config in `~/.config/pipewire/pipewire.conf.d/` — check manually
