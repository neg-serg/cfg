{# Espanso text expander: wayland variant with systemd user service and health check #}
include:
  - pacman_db_warmup

{% from '_imports.jinja' import host, user %}


{% import_yaml 'data/espanso.yaml' as espanso %}

{{ salt['pkg.paru_install']('espanso', espanso.package) }}

{{ salt['user_service.user_service_with_unit']('espanso', espanso.service,
     start_now=[espanso.service],
     requires=['cmd: install_espanso']) }}

espanso_healthcheck:
  cmd.run:
    - name: espanso restart
    - runas: {{ user }}
    - env:
      - XDG_RUNTIME_DIR: {{ host.runtime_dir }}
      - DBUS_SESSION_BUS_ADDRESS: unix:path={{ host.runtime_dir }}/bus
    - unless: espanso status 2>/dev/null | grep -q running
    - require:
      - cmd: espanso_enabled
