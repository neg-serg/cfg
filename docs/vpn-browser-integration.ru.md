# Руководство по интеграции браузера с VPN

Это руководство описывает, как настроить браузер для работы с гибридной VPN-схемой (Xray + sing-box TUN) для доступа к доменам, блокируемым РКН.

## Обзор

Система состоит из:
1. **Xray**: отвечает за транспорт XHTTP+REALITY
2. **sing-box**: поднимает TUN-интерфейс (`sb0`) для VPN-маршрутизации
3. **RKN Domains Fetcher**: автоматически скачивает и обновляет списки заблокированных доменов
4. **VPN Split Router**: динамически определяет блокируемые домены и пускает их через VPN

## Быстрый старт

### 1. Запустите VPN-систему

```bash
# Запустить гибридный VPN
sudo /home/neg/src/cfg/scripts/start-hybrid-vpn.sh

# Или использовать ручную настройку TUN (если auto_route не сработал)
sudo /home/neg/src/cfg/scripts/manual-tun-routes.sh start
```

### 2. Настройте прокси в браузере

#### Zen Browser (рекомендуется)

```bash
# Использовать helper script
/home/neg/src/cfg/scripts/zen-vpn.sh enable
```

Или вручную:
1. Откройте Zen browser
2. Перейдите в `about:preferences#general`
3. Пролистайте до `Network Settings` -> `Settings...`
4. Выберите `Manual proxy configuration`
5. Укажите:
   - SOCKS Host: `127.0.0.1`
   - Port: `10808`
   - включите `Proxy DNS when using SOCKS v5`
6. Нажмите OK

#### Другие браузеры

- **Firefox/Floorp**: те же настройки, что и для Zen browser
- **Chromium-based**: использовать системный прокси или расширение
- **Command line**: задать `ALL_PROXY=socks5://127.0.0.1:10808`

### 3. Проверьте соединение

```bash
# Проверить VPN connectivity
/home/neg/src/cfg/scripts/test-browser-vpn.sh

# Проверить конкретный заблокированный сайт
curl --socks5 127.0.0.1:10808 https://twitter.com
```

## Система доменов РКН

### Автоматические обновления

Система автоматически скачивает и обновляет список доменов, блокируемых РКН:

```bash
# Принудительное обновление
python3 /home/neg/src/cfg/scripts/rkn-domains-fetcher.py fetch --force --integrate

# Проверка статуса
python3 /home/neg/src/cfg/scripts/rkn-domains-fetcher.py status
```

### Systemd-сервисы

Автоматические обновления обрабатываются через systemd timers:

```bash
# Включить автоматические обновления
systemctl --user enable --now rkn-domains-fetcher.timer

# Проверить timer
systemctl --user list-timers | grep rkn-domains

# Ручной запуск
systemctl --user start rkn-domains-fetcher.service
```

### Интеграция с VPN Split Router

Система интегрируется с `vpn-split-router`, чтобы динамически определять блокируемые домены:

```bash
# Проверить статус интеграции
python3 /home/neg/src/cfg/scripts/vpn-split-router-integration.py

# Запустить daemon vpn-split-router
python3 /home/neg/src/cfg/scripts/vpn_split_router.py --daemon
```

## Расширенная настройка

### Кастомный sing-box config с доменами РКН

Сгенерируйте sing-box config, в который включены домены РКН:

```bash
# Сгенерировать config с доменами РКН
python3 /home/neg/src/cfg/scripts/singbox-with-rkn-domains.py --max-domains 1000

# Применить config
cp ~/.config/sing-box-tun/config-with-rkn.json ~/.config/sing-box-tun/config.json
sudo pkill sing-box && sudo /home/neg/src/cfg/scripts/manual-tun-routes.sh start
```

### Ручная TUN-маршрутизация

Если автоматическая маршрутизация не сработала, используйте ручной режим:

```bash
# Запустить ручную маршрутизацию
sudo /home/neg/src/cfg/scripts/manual-tun-routes.sh start

# Остановить ручную маршрутизацию
sudo /home/neg/src/cfg/scripts/manual-tun-routes.sh stop

# Проверить routing tables
ip route show table vpn-tun
```

### Кастомные списки доменов

Для настройки логики обработки доменов отредактируйте конфиг:

```bash
# Edit RKN domains fetcher config
vim ~/.config/rkn-domains-fetcher/config.yaml

# Edit VPN split router config
vim ~/.config/vpn-split-router/config.yaml
```

Пример конфигурации (`~/.config/rkn-domains-fetcher/config.yaml`):

```yaml
settings:
  update_interval_hours: 6
  max_domains: 50000
  fallback_retry_delay_seconds: 3

sources:
  primary: "https://raw.githubusercontent.com/EikeiDev/domains/main/domains.lst"
  backups:
    - "https://github.com/zapret-info/z-i/raw/master/dump.csv"
    - "https://reestr.rublacklist.net/api/v3/domains/"

integration:
  vpn_split_router:
    enabled: true
    auto_mark_vpn: true
    categories:
      ai_services: true
      social_media: true
      video: true
      vpn_proxy: false
```

## Устранение неполадок

### Частые проблемы

1. **TUN-интерфейс не создан**
   ```bash
   # Проверить, что sing-box запущен
   ps aux | grep sing-box

   # Проверить интерфейс
   ip link show sb0

   # Перезапуск с ручной настройкой
   sudo pkill sing-box
   sudo /home/neg/src/cfg/scripts/manual-tun-routes.sh start
   ```

2. **Браузер не использует прокси**
   ```bash
   # Прямой тест прокси
   curl --socks5 127.0.0.1:10808 https://httpbin.org/ip

   # Проверить browser proxy settings
   /home/neg/src/cfg/scripts/test-browser-vpn.sh
   ```

3. **Домены РКН не обновляются**
   ```bash
   # Проверить systemd service
   systemctl --user status rkn-domains-fetcher.service

   # Посмотреть логи
   journalctl --user -u rkn-domains-fetcher.service -f

   # Ручное обновление с debug
   python3 /home/neg/src/cfg/scripts/rkn-domains-fetcher.py fetch --force -v
   ```

4. **VPN работает медленно**
   ```bash
   # Проверить скорость соединения
   /home/neg/src/cfg/scripts/test-vpn-connection.sh

   # Проверить Xray logs
   tail -f ~/.config/xray/access.log
   ```

### Логи и мониторинг

```bash
# Логи sing-box
sudo journalctl -u sing-box-tun.service -f

# Логи Xray
tail -f ~/.config/xray/access.log

# Логи fetcher'а доменов РКН
journalctl --user -u rkn-domains-fetcher.service -f

# Логи VPN split router
python3 /home/neg/src/cfg/scripts/vpn_split_router.py --debug
```

## Обслуживание

### Регулярные обновления

```bash
# Обновить все компоненты
just update-vpn-system

# Или вручную:
# 1. Обновить домены РКН
systemctl --user start rkn-domains-fetcher.service

# 2. Перезапустить VPN-сервисы
sudo systemctl restart sing-box-tun
systemctl --user restart vpn-split-router

# 3. Проверить, что всё работает
/home/neg/src/cfg/scripts/test-browser-vpn.sh
```

### Backup и restore

```bash
# Backup конфигураций
cp -r ~/.config/rkn-domains-fetcher ~/backup/
cp -r ~/.config/vpn-split-router ~/backup/
cp ~/.config/sing-box-tun/config.json ~/backup/

# Restore
cp -r ~/backup/rkn-domains-fetcher ~/.config/
cp -r ~/backup/vpn-split-router ~/.config/
cp ~/backup/config.json ~/.config/sing-box-tun/
```

## Соображения по безопасности

1. **Proxy authentication**: SOCKS5 proxy работает на localhost без аутентификации
2. **Domain filtering**: через VPN идут только домены, блокируемые РКН
3. **Automatic updates**: список доменов обновляется каждые 6 часов
4. **Fallback sources**: есть несколько резервных источников, если основной недоступен
5. **Encryption**: весь VPN-трафик шифруется через Xray+REALITY

## Поддержка

При проблемах или вопросах:
1. Проверить логи: `journalctl --user -u rkn-domains-fetcher.service`
2. Проверить connectivity: `/home/neg/src/cfg/scripts/test-browser-vpn.sh`
3. Manual debug: запускать компоненты с флагом `-v`
4. Проверить статус системы: `systemctl --user list-units | grep -E "(rkn|vpn|sing)"`

## Связанная документация

- VPN Quick Start (docs/vpn-quickstart.ru.md)
- Hybrid VPN Architecture
- [Salt States for VPN](../states/README.md)
- [RKN Domains Fetcher Source Code](../scripts/rkn-domains-fetcher.py)
