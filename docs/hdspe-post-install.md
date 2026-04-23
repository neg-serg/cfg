# RME HDSPe AIO Pro: установка и проверка

## Установлено

- **Модуль ядра**: `snd-hdspe` (DKMS, подписан, автозагрузка)
- **Blacklist**: `snd-hdspm` — `/usr/lib/modprobe.d/hdspe.conf`
- **Утилита**: `~/bin/hdspeconf` (wxWidgets GUI, нужен дисплей)
- **Репозиторий**: весь ADI-2 код удалён и закоммичен

## Карта

| Параметр | Значение |
|---|---|
| Модель | RME HDSPe AIO Pro (multichannel audio controller) |
| PCI | `05:00.0`, vendor:device `RME 3fc6`, driver `snd_hdspe` |
| ALSA | `card 0: HDSPe24048964`, device 0 — playback + capture |
| PW sink | `alsa_output.pci-0000_05_00.0.multichannel-output` («RME AIO Pro») |
| PW source | `alsa_input.pci-0000_05_00.0.multichannel-input` («RME AIO Pro») |
| Дефолтный sink/source | Уже стоит на HDSPe (WirePlumber назначил автоматически) |

## Что работает

- `pw-play` — воспроизведение через PipeWire: OK
- `speaker-test` через прямой ALSA `hw:0,0` — fails with Device busy (PipeWire владеет картой, это нормально)
- `hdspeconf` — запускается при наличии дисплея (GUI для аппаратного микшера AIO Pro)

## PipeWire конфиг

Не требуется. Карта работает с дефолтным WirePlumber. Никакого ремаппинга не нужно — AIO Pro это многоканальное устройство с физическими выходами.

`wireplumber.conf.d/10-default-volume.conf` уже чистый (только `default-sink-volume = 1.0`). ADI-2 референсы удалены.

## Остаточные ADI-2 артефакты

- `~/.config/pipewire/pipewire.conf.d/98-adi2-remap.conf` — удалён
- `~/.local/bin/sink-switch` — удалён
- `/usr/local/bin/rme-usb-trigger` — остался (нужен `sudo rm`)

Артефактов pw-restore-links / pw-tools нет.

## Примечания

- Модуль `snd-hdspe` собран из форка `Schroedingers-Cat/snd-hdspe` (ветка `kernel-compat/v6.16`) — оригинал не собирается на ядре 6.19+
- При перезагрузке `snd-hdspm` заблокирован blacklist-ом, `snd-hdspe` грузится автоматически
- Если карта исчезнет после обновления ядра — пересобрать DKMS: `sudo dkms autoinstall`
