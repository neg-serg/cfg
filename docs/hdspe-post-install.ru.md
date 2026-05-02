# RME HDSPe AIO Pro: установка и проверка

## Установлено

- **Модуль ядра**: `snd-hdspe` (DKMS, подписан, автозагрузка)
- **Blacklist**: `snd-hdspm` — `/usr/lib/modprobe.d/hdspe.conf`
- **Утилита**: `~/bin/hdspeconf` (wxWidgets GUI, нужен дисплей)
- **Репозиторий**: весь ADI-2 код удалён и закоммичен

## Карта

| Параметр | Значение |
|---|---|
| Модель | RME HDSPe AIO Pro (многоканальный аудиоконтроллер) |
| PCI | `05:00.0`, vendor:device `RME 3fc6`, драйвер `snd_hdspe` |
| ALSA | `card 0: HDSPe24048964`, устройство 0 — playback + capture |
| PW sink | `alsa_output.pci-0000_05_00.0.multichannel-output` («RME AIO Pro») |
| PW source | `alsa_input.pci-0000_05_00.0.multichannel-input` («RME AIO Pro») |
| Default sink/source | Уже установлен на HDSPe (WirePlumber auto-assigned) |

## Проверено

- `pw-play` — воспроизведение через PipeWire: OK
- `speaker-test` через прямой ALSA `hw:0,0` — не работает с Device busy (PipeWire владеет картой, ожидаемо)
- `hdspeconf` — запускается с дисплеем (GUI для аппаратного микшера AIO Pro)

## PipeWire конфиг

Не требуется. Работает с дефолтным WirePlumber. Никакого ремаппинга не требуется — AIO Pro многоканальное устройство с физическими выходами.

`wireplumber.conf.d/10-default-volume.conf` чист (только `default-sink-volume = 1.0`). Все ссылки на ADI-2 удалены.

## Помощник маршрутизации PipeWire

Используйте `pw-route` для перемещения активных стерео-потоков PipeWire на именованные пары выходов RME на pro-audio sink:

- `pw-route an` -> `AUX0/AUX1`
- `pw-route aes` -> `AUX2/AUX3`
- `pw-route spdif` -> `AUX4/AUX5`
- `pw-route phones` -> `AUX6/AUX7`
- `pw-route status` -> показать текущие RME playback-линки

Предназначено для HDSPe AIO Pro, работающего как многоканальное PipeWire устройство. Аппаратный мониторинг и субмикширование происходят в `hdspmixer`; `pw-route` только меняет, на какую пару выходов попадает программный поток.

## Остаточные ADI-2 артефакты на диске

- `~/.config/pipewire/pipewire.conf.d/98-adi2-remap.conf` — удалён
- `~/.local/bin/sink-switch` — удалён
- `/usr/local/bin/rme-usb-trigger` — удалён
- `~/.local/bin/pw-restore-links` — удалён
- `~/.local/bin/pw-tools` — удалён
- `~/.config/systemd/user/pw-restore-links.service` — удалён (был pw-restore-links.service)

## Примечания

- `snd-hdspe` собран из форка `Schroedingers-Cat/snd-hdspe` (ветка `kernel-compat/v6.16`) — upstream не собирается на ядре 6.19+
- После перезагрузки `snd-hdspm` заблокирован blacklist-ом, `snd-hdspe` загружается автоматически
- Если карта пропадает после обновления ядра, пересоберите DKMS: `sudo dkms autoinstall`
