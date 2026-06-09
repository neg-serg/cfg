{# KDE Plasma desktop environment: optional session alongside Hyprland #}
{#- @state
   id: desktop.plasma
   purpose: "KDE Plasma desktop environment: packages and config."
   includes: [pacman_db_warmup]
   data_files: [data/packages.yaml]
#}
{% from '_imports.jinja' import host %}

include:
  - pacman_db_warmup

{{ salt['pkg.paru_install']('kde_plasma_packages',
    'plasma-desktop plasma-workspace polkit-kde-agent plasma-wayland-session breeze breeze-icons') }}

kde_session_check:
  file.exists:
    - name: /usr/share/wayland-sessions/plasma.desktop
    - require:
      - cmd: install_kde_plasma_packages
