# Espanso: cross-platform text expander (Wayland variant).
{% from '_imports.jinja' import user %}
{% from '_macros_pkg.jinja' import paru_install %}
{% from '_macros_service.jinja' import user_service_with_unit, _env_block %}
# Espanso: cross-platform text expander (Wayland variant)

# --- Install espanso-wayland from AUR ---
{{ paru_install('espanso', 'espanso-wayland') }}

# --- Systemd user service ---
# Config files managed by chezmoi (dotfiles/dot_config/espanso/)
{{ user_service_with_unit('espanso', 'espanso.service',
     start_now=['espanso.service'],
     requires=['cmd: install_espanso']) }}

# --- Health check: restart espanso if it's not running ---
espanso_healthcheck:
  cmd.run:
    - name: espanso restart
    - runas: {{ user }}
    - env:
{{ _env_block() }}
    - unless: espanso status 2>/dev/null | grep -q running
    - require:
      - cmd: espanso_enabled
