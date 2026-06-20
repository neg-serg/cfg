# Remaining Packages — bluefin-custom-full

**Total original:** 563 | **Covered:** ~454 (360 RPM + 94 host-built) | **Remaining:** 109

---

## Arch-specific / Skip (17)

These are Arch Linux ecosystem packages with no Fedora equivalent.

| Package | Reason |
|---------|--------|
| `base`, `base-devel` | Arch meta-package |
| `linux`, `linux-headers`, `linux-cachyos-headers` | Kernel — Bluefin provides its own |
| `limine` | Bootloader — Fedora uses systemd-boot |
| `pacman-contrib`, `rebuild-detector` | pacman tools |
| `paru`, `paru-debug`, `yay` | AUR helpers — not on Fedora |
| `mkinitcpio` | Arch initramfs — Fedora uses dracut |
| `systemd-resolvconf` | Built into systemd on Fedora |
| `rofi-file-browser-extended-git-debug` | Debug symbols only |
| `ssh-to-age-debug`, `proxypilot-debug` | Debug symbols |

## User-space / Gaming (4)

Installed post-deploy into `$HOME`, not system packages.

| Package | How to install |
|---------|---------------|
| `proton-cachyos` | ProtonUp-Qt |
| `proton-ge-custom-bin` | ProtonUp-Qt → `~/.steam/compatibilitytools.d/` |
| `optiscaler-universal` | Windows DLL — not applicable on Linux |
| `iosevka-neg-fonts` | Custom font — copy TTF to `~/.local/share/fonts/` |

## Truly unavailable (14)

These packages have no public source — repos deleted, Windows-only, or never existed on any platform.

| Package | Reason |
|---------|--------|
| `lazytail-bin` | GitHub repo not found |
| `oports-git` | User's private tool |
| `pixora-icons-git` | User's private icon theme |
| `quickshell`, `quickshell-overview-git` | Huge Qt6 build — needs separate packaging |
| `reddix-bin` | GitHub repo not found |
| `repeater-bin` | GitHub repo not found |
| `resterm-bin` | GitHub repo not found |
| `simutil-bin` | GitHub repo not found |
| `v2rayn-bin` | Windows-only (.NET) |
| `vicinae-bin` | User's private dmenu wrapper |
| `witr-bin` | GitHub repo not found |
| `gvfs-onedrive` | Use rclone instead |
| `gvfs-wsdd` | Not packaged for Fedora |

## Available post-deploy (via cargo/pip/go/flatpak — 25)

These install via fast package managers after first boot. Not worth bundling into the image.

| Package | Install |
|---------|---------|
| `bat` | `cargo install bat` |
| `bottom` | `cargo install bottom` |
| `eza` | `cargo install eza` |
| `fd` | `cargo install fd-find` |
| `dust` | `cargo install du-dust` |
| `erdtree` | `cargo install erdtree` |
| `fclones` | `cargo install fclones` |
| `hexyl` | `cargo install hexyl` |
| `hyperfine` | `cargo install hyperfine` |
| `just` | `cargo install just` |
| `bandwhich` | `cargo install bandwhich` |
| `doggo` | `cargo install doggo` |
| `grex` | `cargo install grex` |
| `htmlq` | `cargo install htmlq` |
| `difftastic` | `cargo install difftastic` |
| `choose` | `cargo install choose` |
| `curlie` | `cargo install curlie` |
| `genact` | `cargo install genact` |
| `dive` | `go install github.com/wagoodman/dive@latest` |
| `himalaya` | `cargo install himalaya` |
| `gist` | `cargo install gist` |
| `gitleaks` | `go install github.com/gitleaks/gitleaks/v8@latest` |
| `jupyterlab` | `pip install jupyterlab` (or `pipx install jupyterlab`) |
| `beets` | `pip install beets` (available as RPM in base) |
| `httpie` | `pip install httpie` (available as RPM in base) |

## Downloadable binaries (21)

Can be downloaded from GitHub Releases post-deploy. Network was unreliable during build.

| Package | Source |
|---------|--------|
| `act-bin` | `github.com/nektos/act` |
| `amdvlk-bin` | AMDVLK (also available as `amdvlk` RPM) |
| `babashka-bin` | Already built (bb) — verify |
| `google-chrome` | `dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm` |
| `hw-probe` | `github.com/linuxhw/hw-probe` |
| `instagram-cli` | `npm install -g instagram-cli` |
| `localsend-bin` | `github.com/localsend/localsend` (also Flatpak) |
| `v2ray` | `github.com/v2fly/v2ray-core` |
| `git-delta` | Already available as `git-delta` RPM |
| `cpufetch` | `github.com/Dr-Noob/cpufetch` |
| `cloudflare-speed-cli` | Available via `cargo` |
| `chromaprint` | Available as `chromaprint` RPM |
| `geoip-database` | Available as `geoipupdate` RPM |
| `gptfdisk` | Available as `gptfdisk` RPM |
| `gitlogue` | `go install` |
| `goimapnotify` | `go install gitlab.com/shackra/goimapnotify@latest` |
| `helix` | Available as `helix` RPM |
| `jujutsu` | Available as `jj` RPM |
| `lua-language-server` | Available as `lua-language-server` RPM |
| `lua53` | Available as `lua` RPM |
| `ripgrep` | Available as `ripgrep` RPM |
