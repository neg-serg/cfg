{# XDG Desktop Portal: screen sharing, file chooser, and sandboxing backends #}
include:
  - pacman_db_warmup

{% from '_imports.jinja' import home, user %}
{% from '_macros_pkg.jinja' import paru_install %}
{% from '_macros_service.jinja' import ensure_dir %}
{% import_yaml 'data/desktop.yaml' as desktop %}

{{ ensure_dir('portal_conf_dir', home ~ '/.config/xdg-desktop-portal', mode='0755') }}

portal_config:
  file.managed:
    - name: {{ home }}/.config/xdg-desktop-portal/hyprland-portals.conf
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0644'
    - replace: False
    - contents: |
        [preferred]
        default=hyprland;gtk
        org.freedesktop.impl.portal.FileChooser=termfilechooser
    - require:
      - file: portal_conf_dir

{{ paru_install('xdg_termfilechooser', desktop.portal_package) }}

portal_restart:
  cmd.run:
    - name: systemctl --user restart {{ desktop.portal_service }}
    - runas: {{ user }}
    - onchanges:
      - file: portal_config
