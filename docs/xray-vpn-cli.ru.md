# Xray VPN - использование из CLI

## Обзор

Используйте импорт конфига для работы с VPN.

AmneziaVPN хранит активный профиль в `~/.config/AmneziaVPN.ORG/AmneziaVPN.conf`.
Импортируйте его в runtime-конфиг `~/.config/sing-box-tun/config.json`.

**Примечание:** Начиная с AmneziaVPN 4.8.14.5 сохранённый конфиг использует **формат Xray** (VLESS Reality).
Сгенерированный `config.json` — это конфигурация Xray, а не sing‑box.

Вы можете:
- Протестировать импортированный конфиг напрямую через Xray (SOCKS5 прокси)
- Сконвертировать его в формат sing‑box для TUN‑маршрутизации (требует ручного соответствия полей)

## Пути

- Исходный конфиг: `~/.config/AmneziaVPN.ORG/AmneziaVPN.conf`
- Сгенерированный runtime-конфиг: `~/.config/sing-box-tun/config.json` (формат Xray)
- TUN-сервис: `sing-box-tun.service` (требует формат sing‑box)

## Использование

### 1. Импорт текущего профиля AmneziaVPN

```bash
scripts/amnezia-import-tun-config.sh import
```

Установленный эквивалент:

```bash
~/.local/bin/amnezia-import-tun-config import
```

Импортер извлекает поле `last_config` из конфигурации AmneziaVPN.
Если импорт завершается ошибкой «could not locate last_config», проверьте, что профиль содержит валидную запись сервера.

### 2. Тестирование импортированного конфига (Xray SOCKS5)

```bash
scripts/test-vpn-connection.sh
```

Скрипт запускает Xray с импортированным конфигом, проверяет подключение через SOCKS5‑прокси (`127.0.0.1:10808`), затем останавливает Xray.

Ручная проверка:

```bash
# Запустить Xray в фоне
~/.local/bin/xray run -config ~/.config/sing-box-tun/config.json &
XRAY_PID=$!

# Тест через curl
curl --max-time 30 --socks5 127.0.0.1:10808 https://httpbin.org/ip

# Остановить Xray
kill $XRAY_PID
```

### 3. TUN‑маршрутизация (sing‑box)

Чтобы использовать импортированный конфиг с `sing-box-tun.service`, его нужно сконвертировать в формат sing‑box.

```bash
scripts/xray-to-singbox.py ~/.config/sing-box-tun/config.json ~/.config/sing-box-tun/config-singbox.json
```

**Примечание:** Конвертер экспериментальный и может создавать невалидные конфиги sing‑box из-за изменений API.
Проверьте результат:

```bash
sing-box check -c ~/.config/sing-box-tun/config-singbox.json
```

Если проверка проходит, запустите TUN-сервис:

## Поток zero-config router

Когда включен `features.network.vpn_split_router`, используйте helper для пересборки состояния и просмотра решений:

```bash
~/.local/bin/vpn-split-router recheck
~/.local/bin/vpn-split-router status
~/.local/bin/vpn-split-router list
```

Пересборка также автоматически запускается через пользовательские `systemd`-юниты `vpn-split-router.timer` и `vpn-split-router.service`.

```bash
systemctl --user status vpn-split-router.timer vpn-split-router.service
```

Временные escape hatch команды для правки состояния:

```bash
~/.local/bin/vpn-split-router mark-vpn claude.ai
~/.local/bin/vpn-split-router mark-direct claude.ai
~/.local/bin/vpn-split-router forget claude.ai
```

`mark-vpn` и `mark-direct` меняют только текущее состояние роутера, пока его не обновит следующая пересборка.
`forget` удаляет только текущую запись состояния; seed-домены могут появиться снова при следующем `recheck` или запуске таймера, а observed-only домены вернутся только если внешний источник заново их обнаружит или вы добавите их вручную.

Запустите TUN-сервис:

```bash
sudo systemctl start sing-box-tun
```

## Диагностика

```bash
# Исходный конфиг
ls -l ~/.config/AmneziaVPN.ORG/AmneziaVPN.conf

# Импортированный runtime-конфиг
ls -l ~/.config/sing-box-tun/config.json

# Тест Xray
~/.local/bin/xray run -test -config ~/.config/sing-box-tun/config.json

# Статус сервиса (если конфиг sing‑box готов)
sudo systemctl status sing-box-tun
journalctl -u sing-box-tun -b --no-pager
```

## Связь с AmneziaVPN

Если профиль AmneziaVPN изменился, перед запуском или перезапуском любого VPN‑клиента выполните импорт заново, чтобы пересоздать `~/.config/sing-box-tun/config.json`.

## Устранение проблем

- **«could not locate last_config in AmneziaVPN.conf»** — профиль может быть пустым или повреждён. Откройте AmneziaVPN GUI, убедитесь, что сервер добавлен и подключен, затем повторите импорт.
- **«invalid serversList JSON»** — импортер ожидает поле `serversList` в JSON‑формате. Если формат изменился, обновите `scripts/amnezia-import-tun-config.sh`.
- **sing‑box сообщает «legacy inbound fields are deprecated»** — конвертер Xray→sing‑box использует устаревший синтаксис inbound. Обновите конвертер или вручную исправьте сгенерированный конфиг sing‑box.
- **TUN-сервис не найден** — включите `vpn_split_router` в `states/data/hosts.yaml` и примените Salt-состояние `network.singbox`.
