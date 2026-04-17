# Xray VPN - использование из CLI

## Обзор

Для TUN VPN теперь используется поток с импортом конфига.

AmneziaVPN по-прежнему хранит исходный профиль в `~/.config/AmneziaVPN.ORG/AmneziaVPN.conf`.
Импортируйте его в runtime-конфиг `~/.config/sing-box-tun/config.json`, затем запускайте `sing-box-tun`.

TUN-сервис читает сгенерированный runtime-конфиг.
Qt settings файл напрямую он не использует.

## Пути

- Исходный конфиг: `~/.config/AmneziaVPN.ORG/AmneziaVPN.conf`
- Сгенерированный runtime-конфиг: `~/.config/sing-box-tun/config.json`
- TUN-сервис: `sing-box-tun.service`

## Использование

Обновите runtime-конфиг после изменения профиля AmneziaVPN:

```bash
scripts/amnezia-import-tun-config.sh import
```

Установленный эквивалент:

```bash
~/.local/bin/amnezia-import-tun-config import
```

Запустите TUN-сервис:

```bash
sudo systemctl start sing-box-tun
```

`sing-box-tun.service` запускает `sing-box` с `~/.config/sing-box-tun/config.json`.

## Диагностика

```bash
ls -l ~/.config/AmneziaVPN.ORG/AmneziaVPN.conf
ls -l ~/.config/sing-box-tun/config.json
sudo systemctl status sing-box-tun
journalctl -u sing-box-tun -b --no-pager
```

## Связь с AmneziaVPN

Если профиль AmneziaVPN изменился, перед запуском или перезапуском `sing-box-tun` заново выполните импорт, чтобы пересоздать `~/.config/sing-box-tun/config.json`.
