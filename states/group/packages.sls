{# Packages group: system packages, AUR installers, mpv scripts, themes #}
{#- @state
   id: group.packages
   purpose: "Packages group: system packages, AUR installers, mpv scripts, themes."
   includes: [custom_pkgs, installers, installers_desktop, installers_mpv, installers_themes, packages, pacman_db_warmup]
#}
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
