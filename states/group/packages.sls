{# Packages group: system packages, AUR installers, mpv scripts, themes #}
# Group: all package management — pacman, installers, custom builds
# Usage: just apply group/packages

include:
  - pacman_db_warmup
  - packages
  - installers
  - installers_mpv
  - installers_desktop
  - installers_themes
  - custom_pkgs
