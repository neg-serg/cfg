{% from '_imports.jinja' import host, home, user %}

{% from '_macros_service_user.jinja' import user_service_enable, user_service_file %}
{% import_yaml 'data/vpn.yaml' as vpn %}
{% set net = host.features.network %}

{% if net.vpn_split_router %}

{{ salt['service.ensure_dir']('vpn_split_router_config_dir', home ~ '/.config/vpn-split-router', mode='0755') }}
{{ salt['service.ensure_dir']('vpn_split_router_state_dir', home ~ '/.local/state/vpn-split-router', mode='0755') }}

vpn_split_router_script:
  file.managed:
    - name: {{ home }}/.local/bin/vpn-split-router
    - source: salt://scripts/vpn_split_router.py
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0755'

vpn_split_router_config:
  file.managed:
    - name: {{ home }}/.config/vpn-split-router/config.yaml
    - source: salt://configs/vpn-split-router.yaml.j2
    - template: jinja
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0644'
    - context:
        router_config: {{ vpn.split_router_config | tojson }}

{{ user_service_file('vpn_split_router_service', 'vpn-split-router.service') }}
{{ user_service_file('vpn_split_router_timer', 'vpn-split-router.timer') }}
{{ user_service_file('vpn_policy_rollback_service', 'vpn-policy-rollback.service') }}
{{ user_service_file('vpn_policy_rollback_timer', 'vpn-policy-rollback.timer') }}

{{ user_service_enable('vpn_split_router_enabled',
    start_now=['vpn-split-router.timer'],
    requires=[
        'file: vpn_split_router_script',
        'file: vpn_split_router_config',
        'file: vpn_split_router_service',
        'cmd: vpn_split_router_service_daemon_reload',
        'file: vpn_split_router_timer',
        'cmd: vpn_split_router_timer_daemon_reload',
    ],
) }}

sing_box_tun_react_service_unit:
  file.managed:
    - name: {{ vpn.split_router.service_unit }}
    - source: salt://units/sing-box-tun-react.service
    - mode: '0644'

sing_box_tun_react_path_unit:
  file.managed:
    - name: {{ vpn.split_router.service_path }}
    - source: salt://units/sing-box-tun-react.path
    - template: jinja
    - mode: '0644'
    - context:
        home: {{ home }}

sing_box_tun_react_daemon_reload:
  cmd.run:
    - name: systemctl daemon-reload
    - onlyif: test -e /run/systemd/system || test -e /etc/systemd/system
    - onchanges:
      - file: sing_box_tun_react_service_unit
      - file: sing_box_tun_react_path_unit

sing_box_tun_react_path_running:
  service.running:
    - name: sing-box-tun-react.path
    - enable: True
    - require:
      - file: sing_box_tun_react_service_unit
      - file: sing_box_tun_react_path_unit
      - cmd: sing_box_tun_react_daemon_reload

{% endif %}

{% if net.vpn_split_router or net.vpn_hybrid %}
amnezia_import_tun_script:
  file.managed:
    - name: {{ vpn.split_router.amnezia_import }}
    - source: salt://scripts/amnezia-import-tun-config.sh
    - mode: '0755'
    - user: root
    - group: root

amnezia_import_tun_user_script:
  file.symlink:
    - name: {{ home }}/.local/bin/amnezia-import-tun-config
    - target: {{ vpn.split_router.amnezia_import }}
    - user: {{ user }}
    - group: {{ user }}
    - makedirs: True
    - require:
      - file: amnezia_import_tun_script

{{ user_service_file('amnezia_import_tun_user_service', 'amnezia-import-tun.service') }}
{% endif %}
