# RME HDSPe AIO Pro: installation & verification

## Installed

- **Kernel module**: `snd-hdspe` (DKMS, signed, auto-load)
- **Blacklist**: `snd-hdspm` — `/usr/lib/modprobe.d/hdspe.conf`
- **Utility**: `~/bin/hdspeconf` (wxWidgets GUI, needs display)
- **Repository**: all ADI-2 code removed and committed

## Hardware map

| Param | Value |
|---|---|
| Model | RME HDSPe AIO Pro (multichannel audio controller) |
| PCI | `05:00.0`, vendor:device `RME 3fc6`, driver `snd_hdspe` |
| ALSA | `card 0: HDSPe24048964`, device 0 — playback + capture |
| PW sink | `alsa_output.pci-0000_05_00.0.multichannel-output` («RME AIO Pro») |
| PW source | `alsa_input.pci-0000_05_00.0.multichannel-input` («RME AIO Pro») |
| Default sink/source | Already set to HDSPe (WirePlumber auto-assigned) |

## Verified

- `pw-play` — playback via PipeWire: OK
- `speaker-test` via direct ALSA `hw:0,0` — fails with Device busy (PipeWire owns the card, expected)
- `hdspeconf` — launches with a display (GUI for AIO Pro hardware mixer)

## PipeWire config

Not needed. Works with default WirePlumber. No remapping required — AIO Pro is a multichannel device with physical outputs.

`wireplumber.conf.d/10-default-volume.conf` is clean (only `default-sink-volume = 1.0`). All ADI-2 references removed.

## Residual ADI-2 artifacts on disk

- `~/.config/pipewire/pipewire.conf.d/98-adi2-remap.conf` — removed
- `~/.local/bin/sink-switch` — removed
- `/usr/local/bin/rme-usb-trigger` — removed

No pw-restore-links / pw-tools artifacts remain.

## Notes

- `snd-hdspe` built from `Schroedingers-Cat/snd-hdspe` fork (`kernel-compat/v6.16` branch) — upstream does not build on kernel 6.19+
- On reboot, `snd-hdspm` is blacklisted, `snd-hdspe` loads automatically
- If the card disappears after a kernel update, rebuild DKMS: `sudo dkms autoinstall`
