# RME HDSPe AIO Pro: установка и проверка

Смотри `docs/hdspe-post-install.md`.

## Установлено

- **Модуль ядра**: `snd-hdspe` (DKMS, подписан, автозагрузка)
- **Blacklist**: `snd-hdspm` — `/usr/lib/modprobe.d/hdspe.conf`
- **Утилита**: `~/bin/hdspeconf` (wxWidgets GUI, нужен дисплей)
- **Репозиторий**: весь ADI-2 код удалён и закоммичен

## Карта

| Параметр | Значение |
|---|---|
| Модель | RME HDSPe AIO Pro |
| PCI | `05:00.0` |
| ALSA | card 0, device 0 |
| PW sink | `alsa_output.pci-0000_05_00.0.multichannel-output` |
| PW source | `alsa_input.pci-0000_05_00.0.multichannel-input` |
| Default sink | HDSPe (автоматически) |

## PipeWire конфиг

Не требуется. Дефолтный WirePlumber. `10-default-volume.conf` чист.

## Остаточные ADI-2 артефакты на диске

- `~/.config/pipewire/pipewire.conf.d/98-adi2-remap.conf` — удалён
- `~/.local/bin/sink-switch` — удалён
- `/usr/local/bin/rme-usb-trigger` — ещё висит (нужен `sudo rm`)
