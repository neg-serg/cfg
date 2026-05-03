{# Niri scrolling-tiling Wayland compositor: package install and session setup #}
{% from '_imports.jinja' import user, home %}
{% from '_macros_pkg.jinja' import paru_install %}
{% from '_macros_service.jinja' import ensure_dir %}

# --- Niri compositor installation ---
# spec skeleton: niri-pkg pkg.installed with refresh: true
# project convention: paru_install macro for AUR packages
{{ paru_install('niri-pkg', 'niri') }}

# spec skeleton: niri-xwayland-satellite pkg.installed with refresh: true
{{ paru_install('niri-xwayland-satellite', 'xwayland-satellite') }}

# spec skeleton: niri-portals pkg.installed with refresh: true
{{ paru_install('niri-portals', 'xdg-desktop-portal-gnome xdg-desktop-portal-gtk') }}

# --- Niri config directory ---
{{ ensure_dir('niri_config_dir', home ~ '/.config/niri', mode='0700', user=user) }}

# --- Niri config file ---
niri_config_file:
  file.managed:
    - name: {{ home }}/.config/niri/config.kdl
    - source: salt://dotfiles/dot_config/niri/config.kdl
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0644'
    - makedirs: true
    - require:
      - file: niri_config_dir

# --- Niri session entry for greetd ---
# Uses absolute path so it works regardless of session-wrapper's PATH.
# Overrides the package-provided niri.desktop (which uses Exec=niri-session
# without full path).
niri_session_entry:
  file.managed:
    - name: /usr/share/wayland-sessions/niri.desktop
    - source: salt://desktop/niri.desktop
    - user: root
    - group: root
    - mode: '0644'
    - makedirs: true
