# VPN через командную строку - Быстрый старт

## 🚀 Самый простой способ (SOCKS5 прокси)

VPN уже может быть запущен! Сначала проверьте:

```bash
# Проверить, работает ли VPN
curl --socks5 127.0.0.1:10808 https://ifconfig.me && echo
```

Если команда выше показывает IP-адрес (не ошибку), VPN уже работает. Используйте его:

### Базовое использование:
```bash
# Любой сайт через VPN
curl --socks5 127.0.0.1:10808 https://google.com

# Или для всей сессии терминала:
export ALL_PROXY=socks5://127.0.0.1:10808
export HTTP_PROXY=socks5://127.0.0.1:10808
export HTTPS_PROXY=socks5://127.0.0.1:10808

# Теперь все команды идут через VPN
curl https://youtube.com      # через VPN
wget https://github.com       # через VPN
```

### Для разных программ:
```bash
# Git
git -c http.proxy=socks5://127.0.0.1:10808 clone https://github.com/...

# Wget
wget -e use_proxy=yes -e socks_proxy=127.0.0.1:10808 https://...

# Python/Node.js
export HTTP_PROXY=socks5://127.0.0.1:10808
export HTTPS_PROXY=socks5://127.0.0.1:10808
python script.py
```

## 🔧 Если VPN не запущен

### 1. Импортировать конфиг из AmneziaVPN:
```bash
scripts/amnezia-import-tun-config.sh import
```

### 2. Запустить VPN:
```bash
# Запустить в фоне
~/.local/bin/xray run -config ~/.config/sing-box-tun/config.json &

# Или запустить в текущем терминале (Ctrl+C для остановки)
~/.local/bin/xray run -config ~/.config/sing-box-tun/config.json
```

### 3. Проверить:
```bash
curl --socks5 127.0.0.1:10808 https://ifconfig.me
```

## 📊 Проверка статуса VPN

Создайте скрипт `~/bin/vpn-status`:

```bash
#!/usr/bin/env bash
if ss -tlnp | grep -q ":10808"; then
    VPN_IP=$(curl --socks5 127.0.0.1:10808 --silent https://ifconfig.me 2>/dev/null || echo "нет ответа")
    DIRECT_IP=$(curl --silent https://ifconfig.me 2>/dev/null || echo "нет ответа")
    echo "SOCKS5 прокси: 127.0.0.1:10808"
    echo "IP через VPN:   $VPN_IP"
    echo "Прямой IP:      $DIRECT_IP"
    if [[ "$VPN_IP" != "$DIRECT_IP" ]] && [[ "$VPN_IP" != "нет ответа" ]]; then
        echo "Статус:         ✅ VPN РАБОТАЕТ (IP изменен)"
    elif [[ "$VPN_IP" != "нет ответа" ]]; then
        echo "Статус:         ⚠️  VPN подключен, но IP не изменился"
    else
        echo "Статус:         ❌ VPN не отвечает"
    fi
else
    echo "SOCKS5 прокси: Не слушает порт 10808"
    echo "Статус:         ❌ VPN не запущен"
fi
```

Использование: `vpn-status`

## 🛠️ Расширенные варианты

### Гибридная схема (TUN интерфейс)
Для автоматической маршрутизации всего трафика:

```bash
# Запустить гибридную схему
scripts/start-hybrid-vpn.sh
```

Это создаст TUN интерфейс `sb0`, через который весь трафик будет идти автоматически.

### Проверка обхода блокировок
```bash
# Сайты, которые обычно заблокированы
for site in "https://x.com" "https://t.me" "https://rutracker.org" "https://www.bbc.com/russian"; do
    echo -n "$site: "
    if timeout 5 curl --socks5 127.0.0.1:10808 --silent --head "$site" 2>/dev/null | head -1 | grep -q "HTTP"; then
        echo "✅ ДОСТУПЕН"
    else
        echo "❌ недоступен"
    fi
done
```

## ❗ Частые проблемы

### "Connection refused" на порту 10808
VPN не запущен. Запустите:
```bash
pkill -f "xray.*config.json" 2>/dev/null
~/.local/bin/xray run -config ~/.config/sing-box-tun/config.json &
```

### VPN подключается, но IP не меняется
1. Обновите конфиг в AmneziaVPN GUI
2. Импортируйте заново: `scripts/amnezia-import-tun-config.sh import`
3. Попробуйте другой сервер в AmneziaVPN

### Некоторые сайты не работают через VPN
Сайт может блокировать VPN IP. Попробуйте:
- Подключиться напрямую (без `--socks5`)
- Другой сервер VPN
- Подождать и повторить

## 💡 Полезные команды

```bash
# Остановить VPN
pkill -f "xray.*config.json"

# Проверить, какие процессы Xray работают
pgrep -af xray

# Посмотреть логи Xray (если запущен в фоне)
~/.local/bin/xray run -config ~/.config/sing-box-tun/config.json
```

## 🎯 Итог

1. **Проверьте**, не запущен ли VPN: `curl --socks5 127.0.0.1:10808 https://ifconfig.me`
2. **Если работает** - используйте `--socks5 127.0.0.1:10808` или настройте переменные окружения
3. **Если не работает** - импортируйте конфиг и запустите Xray
4. **Для автоматической маршрутизации** - используйте гибридную схему

**Самый простой способ навсегда:**
```bash
echo 'export ALL_PROXY=socks5://127.0.0.1:10808' >> ~/.zshrc
echo 'export HTTP_PROXY=socks5://127.0.0.1:10808' >> ~/.zshrc
echo 'export HTTPS_PROXY=socks5://127.0.0.1:10808' >> ~/.zshrc
```
Теперь VPN будет использоваться во всех терминальных сессиях.