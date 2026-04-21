# Анализ проблем с буфером обмена и решения

## Краткое описание проблемы

Во время реализации динамического переключения прокси для Zen Browser были обнаружены несколько проблем с буфером обмена, влияющих на работу clipboard в окружении Hyprland/Wayland.

## Найденные первопричины

### 1. Конфликты между несколькими clipboard-менеджерами
- **vicinae-server** запущен как user service systemd (`vicinae.service`)
- **wl-paste --watch cliphist store** настроен в autostart Hyprland
- **clipcat** (PID-файл есть, но процесс уже мёртв)
- Несколько менеджеров одновременно перехватывали clipboard-события и вызывали deadlock'и

### 2. Зависшие процессы
- **4+ процессов vicinae dmenu** зависали после вызова меню
- **clipcat daemon PID 498127** со stale PID-файлом (`/run/user/1000/clipcatd.pid`)
- Процессы не всегда корректно завершались после работы

### 3. Проблемы синхронизации Wayland/X11 clipboard
- `wl-copy` пишет в Wayland clipboard
- `wl-paste` читает из Wayland clipboard
- X11-приложения (некоторые экземпляры rofi/vicinae) используют X11 clipboard
- Между двумя протоколами нет автоматической синхронизации

### 4. Квоты на временные каталоги
- `wl-copy` падал с ошибкой `Disk quota exceeded` при записи в `/tmp`
- У mount'а `/tmp` включены пользовательские квоты
- Большой объём clipboard-данных или частые операции могли превышать лимиты

## Наблюдавшиеся симптомы

1. **Clipboard menu (`Super+C`)** показывает историю, но не копирует выбранные элементы
2. **Rofi-clipboard** отображает записи, но операция копирования не срабатывает
3. **Ручные `wl-copy`/`wl-paste`** иногда зависают или упираются в timeout
4. **История clipboard не обновляется** - `wl-paste --watch` не захватывает новые копирования
5. **Hyprland keybindings** для clipboard работают ненадёжно

## Реализованные решения

### 1. Fallback-функции для clipboard
Добавлены более надёжные функции `copy_to_clipboard()` и `get_clipboard_content()` в:
- `~/.local/bin/clip`
- `~/.local/bin/rofi-clipboard`

Эти функции:
- сначала пробуют Wayland (`wl-copy`/`wl-paste`) с `TMPDIR=~/tmp`, чтобы обойти квоты
- переходят на X11 (`xclip`), если Wayland не сработал
- умеют работать как с `clipboard`, так и с `primary` X11 selection

### 2. Очистка процессов
- Убиты зависшие процессы `vicinae dmenu`
- Удалён stale PID-файл clipcat
- Обеспечено, чтобы одновременно работал только один clipboard-менеджер

### 3. Обход через TMPDIR
```bash
mkdir -p ~/tmp
echo "text" | TMPDIR=~/tmp wl-copy --foreground
```

### 4. Унифицированные clipboard-скрипты
- **Основной**: `~/.local/bin/clip` (vicinae + cliphist)
- **Альтернатива**: `~/.local/bin/rofi-clipboard` (rofi + cliphist)
- **Монитор**: `~/.local/bin/wayland-clipboard-monitor` (background watcher)

## Текущее рабочее состояние

✅ **Работает:**
- прямые команды `wl-copy` / `wl-paste`
- сохранение истории в `cliphist`
- получение и индексация clipboard-событий через `vicinae-server`
- меню `Super+C`, показывающее историю из `cliphist`

⚠️ **Оставшиеся проблемы:**
- редкие зависания процессов ещё нужно наблюдать
- нужен более надёжный autostart clipboard-менеджера
- синхронизацию Wayland/X11 можно сделать устойчивее

## Рекомендации по профилактике

1. **Один clipboard-менеджер**: выбрать что-то одно - либо `vicinae-server`, либо `wl-paste --watch cliphist store`

2. **Скрипт мониторинга процессов**:
```bash
#!/bin/bash
# Kill vicinae dmenu processes older than 30 seconds
ps aux | grep "vicinae dmenu" | grep -v grep | while read line; do
    pid=$(echo $line | awk '{print $2}')
    age=$(ps -o etimes= -p "$pid" 2>/dev/null)
    if [[ "$age" -gt 30 ]]; then
        kill -9 "$pid"
    fi
done
```

3. **Autostart configuration** (`~/.config/hypr/autostart.conf`):
```bash
# Ensure clipboard manager starts
exec-once = wl-paste --watch cliphist store &
# OR
exec-once = systemctl --user start --no-block vicinae.service
```

4. **Регулярная очистка**:
```bash
# Clean stale PID files
rm -f /run/user/1000/clipcatd.pid
# Clear /tmp if quotas are hit
find /tmp -user $USER -type f -mtime +1 -delete
```

## Связанные файлы

- `~/.local/bin/clip` - основной clipboard menu script
- `~/.local/bin/rofi-clipboard` - альтернативное меню на rofi
- `~/.config/hypr/autostart.conf` - autostart configuration
- `~/.config/hypr/bindings.conf` - keybinding `Super+C`
- `~/.cache/cliphist/db` - база истории clipboard
- `/run/user/1000/clipcatd.pid` - PID-файл clipcat (часто stale)

## Команды для отладки

```bash
# Check running processes
ps aux | grep -E "(vicinae|clipcat|cliphist|wl-paste)"

# Test clipboard functionality
echo "test" | wl-copy && sleep 0.5 && timeout 1 wl-paste

# Check cliphist entries
cliphist list | tail -5

# Check Wayland display
echo $WAYLAND_DISPLAY

# Check /tmp usage
df -h /tmp
```

---

*Документ создан: 2026-04-21*
*Связанная работа: реализация динамического переключения прокси, интеграция с Zen Browser*
