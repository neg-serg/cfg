# Миграция с Hyprland на Niri — примечания

## Обзор

Эта миграция заменяет Wayland-композитор Hyprland на Niri, сохраняя скроллируемый тайлинг, VRR (Variable Refresh Rate) и поддержку 10‑битного цвета. Цель — минимальная регрессия производительности и операционная прозрачность.

**Статус:** в разработке (протестировано только в оконном режиме).  
**Цель:** рабочая станция CachyOS с AMD GPU, монитор DP‑2 (3840×2160 @240 Гц, масштаб 2.0).  
**Salt state:** `states/desktop/niri.sls` устанавливает Niri и зависимости; конфиг управляется через `dotfiles/dot_config/niri/config.kdl`.

## Установленные пакеты

- `niri‑bin` (AUR) — композитор Niri
- `xwayland‑satellite` — поддержка XWayland
- `xdg‑desktop‑portal‑gnome`, `xdg‑desktop‑portal‑gtk` — интеграция порталов

**Опционально:** `zen‑browser‑bin` (уже установлен), `surfingkeys‑extension` (расширение браузера).

## Отличия конфигурации

### Монитор/Вывод

| Hyprland (`monitorv2`) | Niri (`output`) |
|------------------------|-----------------|
| `output = DP‑2`        | `output "DP‑2"` |
| `mode = 3840x2160@240` | `mode "3840x2160@240"` |
| `position = 0x0`       | `position x=0 y=0` |
| `scale = 2`            | `scale 2.0` |
| `vrr = 3`              | `variable‑refresh‑rate` |
| `bitdepth = 10`        | *Не настраивается* (полагается на автоопределение DRM/KMS) |

Отключённый монитор (`DP‑1`) установлен в `off`.

### Раскладка и визуал

| Hyprland | Niri |
|----------|------|
| `gaps_in = 0`, `gaps_out = 0` | `gaps 0` |
| `border_size = $border_size` | `border { off; width 1; … }` |
| `col.active_border = …` | `focus‑ring { active‑color "#7fc8ff"; … }` |
| `col.inactive_border = …` | `focus‑ring { inactive‑color "#505050"; … }` |
| `rounding = $rounding` | *Нет прямого аналога* (Niri не поддерживает скругление окон) |
| `blur { enabled = true; … }` | `shadow { off; … }` (нет поддержки размытия) |
| `allow_tearing = true` | *Нет аналога* (может увеличить задержку ввода) |
| `direct_scanout = true` | *Нет аналога* |

**Скроллируемая раскладка:**

| Hyprland (`scrolling`) | Niri |
|------------------------|------|
| `column_width = 0.5` | `default‑column‑width { proportion 0.5; }` |
| `explicit_column_widths = 0.5, 1.0` | `preset‑column‑widths { proportion 0.5; proportion 1.0; }` |
| `fullscreen_on_one_column = true` | *Нет аналога* |
| `follow_focus = true` | *Нет аналога* |
| `follow_min_visible = 0.5` | *Нет аналога* |
| `direction = right` | *Нет аналога* (Niri всегда скроллит горизонтально) |

### Ввод и клавиатура

| Hyprland (`input`) | Niri (`input`) |
|--------------------|----------------|
| `kb_layout = us,ru` | `keyboard { xkb { layout "us,ru"; } }` |
| `repeat_rate = 35` | `repeat‑rate 35` |
| `repeat_delay = 250` | `repeat‑delay 250` |
| `touchpad { tap = true; natural_scroll = true; }` | `touchpad { tap; natural‑scroll; }` |

### Привязки клавиш

| Hyprland | Niri |
|----------|------|
| `$M4 = SUPER` | `Mod` (Super на TTY, Alt в оконном режиме) |
| `$C = Control` | `Ctrl` |
| `$S = Shift` | `Shift` |
| `bind = $M4, h, layoutmsg, focus l` | `Mod+H { focus‑column‑left; }` |
| `bind = $M4, j, layoutmsg, focus d` | `Mod+J { focus‑window‑down; }` |
| `bind = $M4, k, layoutmsg, focus u` | `Mod+K { focus‑window‑up; }` |
| `bind = $M4, l, layoutmsg, focus r` | `Mod+L { focus‑column‑right; }` |
| `bind = $M4, mouse_down, workspace, e+1` | `Mod+Page_Down { focus‑workspace‑down; }` |
| `bind = $M4, mouse_up, workspace, e-1` | `Mod+Page_Up { focus‑workspace‑up; }` |
| `bindl = $M4, Return, exec, kitty …` | `Mod+Return { spawn "kitty" "--single‑instance"; }` |
| `$menu = vicinae toggle` | `Mod+D { spawn "vicinae" "toggle"; }` |
| `$browser = zen‑browser` | `Mod+Shift+D { spawn "zen‑browser"; }` |

Привязки скриншотов (`Print`, `Ctrl+Print`, `Alt+Print`) — стандартные для Niri.

### Правила окон

| Hyprland (`match:class`) | Niri (`app‑id`) |
|--------------------------|-----------------|
| `match:class ^(zen\|floorp\|…)` | `match app‑id=r#"^zen$"#` и т.д. |
| `match:class ^(qt5ct\|wine\|…)` | `match app‑id=r#"^qt5ct$"#` и т.д. с `open‑floating true` |
| `match:title "^Picture‑in‑Picture$"` | `match title="^Picture‑in‑Picture$"` с `open‑floating true` |

## Отсутствующие возможности

1. Явная настройка `bitdepth` — Niri полагается на автоопределение DRM/KMS.
2. `allow_tearing` — аналог отсутствует (возможно увеличение задержки ввода).
3. `direct_scanout` — аналог отсутствует.
4. Некоторые возможности скроллируемого тайлинга (`fullscreen_on_one_column`, `follow_focus` и др.).
5. Скругление углов окон и размытие фона.
6. Настройка прозрачности окон.



## Чек‑лист тестирования

- [ ] **10‑битные градиенты** — визуальное сравнение с Hyprland (используйте `mpv --vo=gpu --gpu‑context=wayland --target‑peak=auto` с тестовым градиентом).
- [ ] **VRR включён** — выполните `niri msg outputs` и проверьте `vrr‑capable: true`.
- [ ] **Все привязки клавиш работают** — проверьте навигацию, переключение рабочих столов, запуск приложений.
- [ ] **Правила окон применяются корректно** — проверьте окна браузера, плавающие утилиты, PiP.
- [ ] **Скрипт истории фокуса** — запустите `niri‑focus‑hist` в фоне, откройте два окна, выполните `--switch`.
- [ ] **Субъективная оценка задержки ввода** — сравните ощущения от мыши и переключения окон.
- [ ] **XWayland‑приложения** — запустите X11-приложения (например, `xeyes`) и проверьте их работу.
- [ ] **Интеграция порталов** — диалоги скриншотов и выбора файлов.

## Процедура отката

При критических проблемах:

1. Вернуть Hyprland как основной композитор в pillar Salt.
2. Удалить пакеты Niri (`yay -Rns niri‑bin xwayland‑satellite`).
3. Конфигурация Hyprland остаётся на месте.

Миграция спроектирована как неразрушающая: Hyprland остаётся установленным и настроенным.

## Известные проблемы

- **Предположение о формате адресов** — скрипт истории фокуса предполагает, что адреса окон Niri — это hex-строки с префиксом `0x`. Это нужно проверить при тестировании в оконном режиме и исправить при необходимости.
- **Отсутствует подписка `window‑opened`** — скрипт подписывается только на события `window‑closed` и `window‑focused`, что достаточно для отслеживания фокуса.
- **Нет модульных тестов для скрипта истории фокуса** — контрактные тесты добавлены (`tests/test_niri_focus_hist.py`), но интеграционные тесты требуют запущенного экземпляра Niri.

## Следующие шаги

1. **Task 9** — Временно установить Niri и протестировать в оконном режиме.
2. **Task 10** — Принять решение о полном переходе или откате на основе результатов тестов.
3. Если переход состоялся: обновить Salt pillar для включения Niri, опционально отключить Hyprland.
4. Если откат: оставить Hyprland основным композитором и архивировать конфиг Niri для будущей оценки.