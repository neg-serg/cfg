# Implementation Plan: Port Chezmoi Configs to Guix (fixed)

## Phase 0: Channel Audit (new)

### 0.1 Nonguix — already available (don't re-package)
Packages confirmed in nonguix that replace custom channel:
| Custom channel | Nonguix | Action |
|---|---|---|
| steam (broken) | steam ✅ | Use nonguix |
| lutris (broken) | lutris ✅ | Use nonguix |
| firefox (missing) | firefox ✅ | Use nonguix |
| google-chrome | google-chrome-stable ✅ | Use nonguix |
| vscode | vscode ✅ | Use nonguix |
| discord | discord ✅ | Use nonguix |
| spotify | spotify ✅ | Use nonguix |

### 0.2 Flatpak — alternative for GUI apps
- bottles, discord, spotify, vscode — all on Flathub
- Pros: no compilation, always latest
- Cons: sandboxed, larger disk usage

### 0.3 What stays in custom channel
- CLI tools not in any channel (yazi, zellij, ollama, xray, zapret2, etc.)
- Custom fonts (iosevka-neg)
- Hyprland tools (vicinae, hyprscratch)

### 0.4 Recommendation
1. Add nonguix channel to system config → steam, lutris, firefox, chrome
2. Keep custom channel for unique tools
3. Use Flatpak for bottles (already done on VM)
- ❌ JetBrains Mono — НЕ нужен (пользователь использует кастомную Iosevka Neg)
- ❌ `guix install` — НЕ использовать, только правка system config + re-init
- ✅ Qt: kvantum, qt5ct, qt6ct, qt5-wayland, qt6-wayland — добавить в конфиг
- ✅ Шрифты: iosevka-neg, iosevkaterm-nerd-fonts, iosevka-nerd-fonts — уже в канале

## Задачи

### 1. System config: добавить Qt + fonts
- Добавить `"qt5ct" "qt6ct" "qt5-wayland" "qt6-wayland"` в specification->package
- Kvantum — уже в all.scm
- Шрифты — уже в all.scm, не нужен JetBrains

### 2. Курсор Alkano-aio
- Создать `alkanocursors.scm` в канале
- Git clone + copy в `/share/icons/`

### 3. GTK тема Flight-Dark-GTK
- Проверить наличие, упаковать если нет

### 4. Копирование chezmoi на /mnt/guix
- `sudo cp -r ~/.local/share/chezmoi → /mnt/guix/home/neg/`
- 1028 файлов, нужно сохранить права

### 5. Final re-init
- Все изменения в одном `guix system init`
