# Guix System Deployment Order

## Quick Start

    cd ~/cfg-channel/guix
    guile deploy.scm

## Steps

### 0. Bootstrap Key
Prompts for AGE-SECRET-KEY or GPG key to unlock gopass.
Skip to continue without secrets.

### 1. System Reconfigure
Copies system-config.scm to /etc/config.scm, runs guix system reconfigure.
Substitutes: Yandex only (Bordeaux removed — blocked from Russia).
Guix daemon: --cores=16 --max-jobs=8.

### 2. Build Custom Packages
Builds all .scm files in channel/custom/packages/.
Skips known-broken packages (skip-list in deploy.scm).
Installs built packages to ~/.guix-profile.

### 3. Chezmoi Dotfiles
Clones neg-serg/cfg to ~/.local/share/chezmoi, runs chezmoi apply.

### 4. Gopass
Clones or inits password store. Verifies critical secrets.

### 5. Developer Tools
pip: debugpy, mypy, docutils, httpx
npm: claude-code, codex

### 6. Configs
- ~/.config/zsh-guix/.zshenv — PATH, proxy, p10k
- ~/.config/zsh-guix/.zshrc — plugins + guix pull wrapper
- ~/.config/mpd/mpd.conf
- ~/.config/guix/channels.scm — authenticated channel

### 7. Services
Restarts ssh-daemon (port 2222), starts mpd, unbound, kanata, mpdas.

### 8. User Extras
Builds protontricks if possible.

## Post-Deploy

    source ~/.config/zsh-guix/.zshenv
    guix pull  # uses --cores=16 --max-jobs=8 via wrapper
