{# XDG Desktop Portal: screen sharing, file chooser, and sandboxing backends #}
{#- @state
   id: desktop.portal
   purpose: "XDG Desktop Portal: screen sharing, file chooser, and sandboxing backends."
   includes: [pacman_db_warmup]
   data_files: [data/desktop.yaml]
#}
include:
  - pacman_db_warmup

{% from '_imports.jinja' import home, user %}

{% import_yaml 'data/desktop.yaml' as desktop %}

{{ salt['service.ensure_dir']('portal_conf_dir', home ~ '/.config/xdg-desktop-portal', mode='0755', user=user) }}

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

{{ salt['pkg.paru_install']('xdg_termfilechooser', desktop.portal_package) }}

portal_restart:
  cmd.run:
    - name: systemctl --user restart {{ desktop.portal_service }}
    - runas: {{ user }}
    - onchanges:
      - file: portal_config
