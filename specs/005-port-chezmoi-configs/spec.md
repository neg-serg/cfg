# Port Chezmoi Dotfiles & User Config to Guix System

**Feature**: `005-port-chezmoi-configs`
**Created**: 2026-06-17
**Status**: Specified

## Problem

After installing Guix System with 253+ packages, the user's desktop environment is missing personal configurations managed by chezmoi: Zsh setup, Hyprland bindings, fonts, cursors, themes, and 50+ application configs.

## Scope

### In scope
- **Fonts**: JetBrainsMono Nerd Font, FiraCode Nerd Font, Iosevka Neg (custom), IosevkaTerm Nerd Font, Material Design Icons
- **Cursors**: Alkano-aio cursor theme
- **GTK themes**: Flight-Dark-GTK
- **Shell**: Zsh with plugins (powerlevel10k, fast-syntax-highlighting, history-substring-search, you-should-use, fzf-completion)
- **Dotfiles**: chezmoi-managed configs for hyprland, waybar, wofi, neovim, kitty, alacritty, ghostty, dunst, mako, aria2, beets, mpd, ncmpcpp, neomutt, isync, vdirsyncer, khal, supercollider, mangohud, kvantum, aliae, amfora, Antigravity, borg, cava, clipcat, handlr, hishtory, kanata, lazydocker, lazysql, lazyjournal, networkmanager-dmenu, newsraft, niri, ollama, proxypilot, rofi, tessen, watchexec, wezterm, wiremix, yazi, youtube-tui, zathura, zellij, zen-browser

### Out of scope
- System-level configs (greetd, sshd, network-manager) — already in system config
- Package installation — done via `guix system init`
- Hyprland compositor itself — already installed

## User Scenarios

1. **First boot**: User logs in via greetd, Hyprland launches with their familiar keybindings, waybar shows their status bar, terminal opens with their Zsh theme
2. **Application launch**: All apps (kitty, neovim, zathura, mpv, etc.) open with user's saved preferences
3. **Font rendering**: Iosevka Nerd Font is used in terminal, JetBrainsMono in editor — visually identical to current Arch setup

## Functional Requirements

1. Fonts must be installed and registered with fontconfig before first login
2. Chezmoi must apply all dotfiles to `/home/neg/` before first Wayland session
3. Zsh plugins (powerlevel10k, syntax highlighting) must be sourced from `~/.config/zsh/`
4. Cursor theme must be selectable by `gsettings` and visible in Hyprland
5. GTK theme must apply to all GTK3/GTK4 applications

## Success Criteria

- `fc-list | grep Iosevka` returns results
- `chezmoi diff` shows no unapplied changes
- Hyprland starts with correct keybindings (Super+Enter → kitty, Super+D → wofi)
- `gsettings get org.gnome.desktop.interface cursor-theme` returns 'Alkano-aio'

## Key Entities

- **Font packages**: `font-iosevka-neg`, `font-iosevkaterm-nerd-fonts`, `font-iosevka-nerd-fonts`, `font-material-design-icons` (already in channel)
- **Chezmoi source**: `~/.local/share/chezmoi` (210+ managed files)
- **System config**: `/tmp/host-one-shot.scm` → needs chezmoi auto-apply on first login
- **Cursor**: needs packaging (AUR: `alkano-cursors`)

## Dependencies

- chezmoi (installed)
- git (installed)
- font packages (in custom channel)
- cursor theme (needs packaging or direct install)
- GTK theme (needs packaging or direct install)
