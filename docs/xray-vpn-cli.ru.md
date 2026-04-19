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

## Гибридная схема (Xray + sing-box TUN)

Для конфигураций AmneziaVPN, использующих XHTTP транспорт (специфичный для Xray), прямое преобразование в sing-box может не работать, потому что sing-box не поддерживает XHTTP. Гибридный подход работает:

1. **Xray** запускает оригинальный конфиг AmneziaVPN с XHTTP+REALITY, предоставляя SOCKS5 прокси на порту 10808.
2. **sing-box** создает TUN интерфейс и маршрутизирует трафик через SOCKS5 прокси Xray.

**Шаги:**

```bash
# Запустить гибридный VPN
scripts/start-hybrid-vpn.sh

# Или вручную:
scripts/start-hybrid-vpn.sh ~/.config/sing-box-tun/config.json ~/.config/sing-box-tun/config-singbox-hybrid-final.json
```

**Файлы конфигурации:**

- Оригинальный конфиг Xray: `~/.config/sing-box-tun/config.json`
- Гибридный конфиг sing-box: `~/.config/sing-box-tun/config-singbox-hybrid-final.json`
- Скрипт конвертера: `scripts/xray-to-singbox.py` (обновлен с правильным синтаксисом адреса TUN)

**Конфигурация TUN для sing-box 1.13+:**

Sing-box 1.12.0 удалил устаревшие поля `inet4_address`/`inet6_address`. Используйте единое поле `address`:

```json
{
  "type": "tun",
  "tag": "tun-in",
  "interface_name": "sb0",
  "address": ["172.19.0.1/30", "fd00::1/126"],
  "mtu": 1500,
  "stack": "mixed",
  "auto_route": true,
  "strict_route": false,
  "endpoint_independent_nat": true
}
```

**Тестирование:**

Гибридная схема предоставляет:
- TUN интерфейс `sb0` с автоматической маршрутизацией
- Раздельную маршрутизацию: приватные IP идут напрямую, внешний трафик идет через VPN
- DNS через локальный резолвер (223.5.5.5) с fallback на TLS (1.1.1.1)

Протестируйте с `scripts/test-hybrid-routing.sh`.

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

# Быстрая проверка статуса VPN
scripts/check-vpn-status.sh

# Ручная проверка статуса
if ss -tlnp | grep -q ":10808"; then
    echo "SOCKS5 прокси слушает порт 127.0.0.1:10808"
    curl --socks5 127.0.0.1:10808 https://ifconfig.me 2>/dev/null && echo "VPN отвечает" || echo "VPN не отвечает"
else
    echo "SOCKS5 прокси НЕ слушает"
fi
```

## Связь с AmneziaVPN

Если профиль AmneziaVPN изменился, перед запуском или перезапуском любого VPN‑клиента выполните импорт заново, чтобы пересоздать `~/.config/sing-box-tun/config.json`.

## Устранение проблем

### Проблемы с SOCKS5 прокси

- **«Connection refused» на порту 10808** — Xray не запущен. Запустите:
  ```bash
  ~/.local/bin/xray run -config ~/.config/sing-box-tun/config.json &
  ```

- **«curl: (7) Couldn't connect to server»** — Проверьте, слушает ли порт 10808:
  ```bash
  ss -tlnp | grep :10808
  ```
  Если нет, Xray мог упасть. Проверьте логи:
  ```bash
  ~/.local/bin/xray run -config ~/.config/sing-box-tun/config.json
  ```

- **VPN подключается, но IP не меняется** — VPN сервер может быть заблокирован. Попробуйте:
  1. Обновить конфиг AmneziaVPN (переимпортировать)
  2. Попробовать другой сервер в AmneziaVPN GUI
  3. Проверить, работает ли прямое подключение: `curl https://ifconfig.me`

- **«curl: (56) Recv failure: Connection reset by peer»** — VPN сервер может быть перегружен или заблокирован. Подождите и повторите.

### Проблемы с импортом

- **«could not locate last_config in AmneziaVPN.conf»** — профиль может быть пустым или повреждён. Откройте AmneziaVPN GUI, убедитесь, что сервер добавлен и подключен, затем повторите импорт.
- **«invalid serversList JSON»** — импортер ожидает поле `serversList` в JSON‑формате. Если формат изменился, обновите `scripts/amnezia-import-tun-config.sh`.

### Проблемы с TUN/Sing-box

- **sing‑box сообщает «legacy inbound fields are deprecated»** — конвертер Xray→sing‑box использует устаревший синтаксис inbound. Обновите конвертер или вручную исправьте сгенерированный конфиг sing‑box.
- **TUN-сервис не найден** — включите `vpn_split_router` в `states/data/hosts.yaml` и примените Salt-состояние `network.singbox`.
- **«missing interface address» в sing-box** — Обновите конфиг TUN для использования поля `address` вместо устаревших `inet4_address`/`inet6_address`.

### Общие проблемы

- **Медленная скорость через VPN** — Нормально из-за шифрования и расстояния. Попробуйте:
  - Другой VPN сервер
  - Сервер ближе к вам
  - SOCKS5 вместо TUN (меньше накладных расходов)

- **Некоторые сайты не работают через VPN** — Сайт может блокировать VPN IP. Попробуйте:
  - Прямое подключение для этого сайта
  - Другой VPN сервер
  - Подождать и повторить позже

## Автоматическое развертывание через Salt

Для автоматической установки и настройки гибридной схемы VPN (Xray + sing-box TUN) используйте Salt состояния.

### Включение гибридной VPN

1. **Включите флаги в конфигурации хоста** (`states/data/hosts.yaml`):
   ```yaml
   features:
     network:
       vpn_hybrid: true
       xray: true
       singbox: true
   ```

2. **Примените Salt состояния**:
   ```bash
   sudo salt-call --local state.apply network,services
   ```

   Или используйте скрипт-помощник:
   ```bash
   scripts/enable-vpn-hybrid.sh --enable-flags --apply
   ```

3. **Импортируйте конфигурацию AmneziaVPN** (если ещё не сделано):
   ```bash
   amnezia-import-tun-config import
   ```

4. **Запустите сервисы**:
   ```bash
   sudo systemctl start xray
   sudo systemctl start sing-box-tun-hybrid
   ```

### Что устанавливается

- **Xray**: Устанавливается через AUR (пакет `xray`), конфигурация копируется из `~/.config/sing-box-tun/config.json` в `/etc/xray/config.json`
- **Sing-box**: Устанавливается через pacman (пакет `sing-box-bin`), capabilities `cap_net_admin,cap_net_raw,cap_net_bind_service`
- **Гибридный конфиг sing-box**: `~/.config/sing-box-tun/hybrid-config.json` (TUN + SOCKS outbound на localhost:10808)
- **Systemd юниты**: 
  - `xray.service` (использует конфиг из /etc/xray/config.json)
  - `sing-box-tun-hybrid.service` (зависит от xray.service, создаёт TUN интерфейс sb0)

### Ручной запуск без systemd

```bash
# Запуск Xray
xray run -config ~/.config/sing-box-tun/config.json &

# Запуск sing-box с гибридным конфигом
sing-box run -c ~/.config/sing-box-tun/hybrid-config.json
```

### Проверка статуса

```bash
# Проверить статус сервисов
sudo systemctl status xray sing-box-tun-hybrid

# Проверить VPN подключение через SOCKS5
curl --socks5 127.0.0.1:10808 https://ipinfo.io/json

# Проверить маршрутизацию через TUN
ping -c 1 1.1.1.1
```

### Отключение гибридной VPN

1. Остановите сервисы:
   ```bash
   sudo systemctl stop xray sing-box-tun-hybrid
   ```

2. Отключите флаги в `hosts.yaml`:
   ```yaml
   features:
     network:
       vpn_hybrid: false
       xray: false
       singbox: false
   ```

3. Примените состояния Salt для удаления конфигурации:
   ```bash
   sudo salt-call --local state.apply network,services
   ```
