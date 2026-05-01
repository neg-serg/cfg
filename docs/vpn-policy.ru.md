# Policy Layer для VPN Split Router

Явные правила маршрутизации: always-direct / always-vpn, с автооткатом по таймеру.

## Концепция

Policy layer — это слой явных правил, которые имеют **высший приоритет** над probe-based маршрутизацией:

```
vpn-policy-direct  ← highest priority (always-direct из policy)
vpn-policy-vpn     ← always-vpn из policy
vpn-split-router-managed  ← probe-based (автоматическое обнаружение)
default route      ← всё остальное
```

Хранятся в `~/.config/vpn-split-router/policy.yaml`.

## Команды

### Управление правилами

```bash
# Добавить домен в always-direct (всегда напрямую, без VPN)
vpn-split-router policy add-direct google.com youtube.com

# Добавить домен в always-vpn (всегда через VPN)
vpn-split-router policy add-vpn netflix.com spotify.com

# Удалить домен из policy (из любой секции)
vpn-split-router policy remove netflix.com

# Просмотреть текущий policy
vpn-split-router policy show
```

### Применение и автооткат (safety net)

```bash
# 1. Применить policy к sing-box конфигу
#    → создаётся бэкап policy.yaml → policy.yaml.rollback
#    → запускается таймер vpn-policy-rollback.timer (5 минут)
vpn-split-router policy apply

# 2. Если всё работает — подтвердить изменения
#    → удаляется бэкап
#    → отключается таймер
vpn-split-router policy confirm

# 3. Если что-то сломалось — откатиться
#    → policy.yaml.rollback копируется обратно
#    → sing-box конфиг синхронизируется заново
vpn-split-router policy rollback
```

**Важно**: если не выполнить `confirm` в течение 5 минут, таймер сам выполнит `rollback`.

### Синхронизация

```bash
# Принудительно применить текущий policy к sing-box (без бэкапа и таймера)
vpn-split-router policy sync
```

## Интеграция с recheck

При `vpn-split-router recheck` policy правила автоматически синхронизируются в routing (после probe-based правил). Отдельный `policy sync` не требуется.

## Как это работает

1. `policy add-direct` / `policy add-vpn` — только редактируют `policy.yaml`, не трогают routing
2. `policy apply` — бэкапит `policy.yaml` → `policy.yaml.rollback`, запускает `systemctl --user start vpn-policy-rollback.timer`, синхронизирует в sing-box
3. `vpn-policy-rollback.timer` — systemd user timer, `OnActiveSec=5min`, запускает `vpn-policy-rollback.service`
4. `vpn-policy-rollback.service` — `ExecStart=%h/.local/bin/vpn-split-router policy rollback`
5. `policy confirm` — удаляет бэкап и останавливает таймер
6. `policy rollback` — восстанавливает `policy.yaml` из бэкапа и синхронизирует

### Правила в sing-box конфиге

В `~/.config/sing-box-tun/config.json` появляются правила с тегами:

```json
{
  "tag": "vpn-policy-direct",
  "domain_suffix": ["google.com"],
  "outbound": "direct"
}
```

```json
{
  "tag": "vpn-policy-vpn",
  "domain_suffix": ["netflix.com"],
  "outbound": "vpn"
}
```

## Пример полного цикла

```bash
# Явно указать маршруты
vpn-split-router policy add-direct   google.com youtube.com yandex.ru
vpn-split-router policy add-vpn      netflix.com spotify.com chatgpt.com

# Применить с автооткатом
vpn-split-router policy apply

# Проверить, что сайты открываются как надо
curl -I https://google.com
curl --socks5 127.0.0.1:10808 -I https://netflix.com

# Если всё ок — зафиксировать
vpn-split-router policy confirm

# Если что-то не так — можно откатиться вручную
vpn-split-router policy rollback
```

## Типичные сценарии

| Сценарий | Что делать |
|----------|-----------|
| Сайт работает медленно через VPN | `vpn-split-router policy add-direct example.com && vpn-split-router policy apply` |
| Сайт не открывается без VPN | `vpn-split-router policy add-vpn example.com && vpn-split-router policy apply` |
| Хочу сбросить все правила | `rm ~/.config/vpn-split-router/policy.yaml && vpn-split-router recheck` |
| Применил и всё сломалось | Ничего не делать — через 5 минут откатится само, или `vpn-split-router policy rollback` |

## Устройство файлов

- `~/.config/vpn-split-router/policy.yaml` — текущие правила
- `~/.config/vpn-split-router/policy.yaml.rollback` — бэкап (после `apply`, до `confirm`)
- `~/.config/systemd/user/vpn-policy-rollback.service` — systemd unit для rollback
- `~/.config/systemd/user/vpn-policy-rollback.timer` — systemd timer на 5 минут
