{% from '_imports.jinja' import host, home, user %}
{% from '_macros_service.jinja' import ensure_dir, user_service_enable, user_service_file %}
{% set net = host.features.network %}

# --- VM Bridge: br0 for KVM/libvirt VMs ---
{% if net.vm_bridge %}
vm_bridge_netdev:
  file.managed:
    - name: /etc/systemd/network/10-br0.netdev
    - makedirs: True
    - mode: '0644'
    - contents: |
        [NetDev]
        Name=br0
        Kind=bridge

vm_bridge_network:
  file.managed:
    - name: /etc/systemd/network/10-br0.network
    - makedirs: True
    - mode: '0644'
    - source: salt://configs/br0.network

vm_bridge_firewall:
  cmd.run:
    - name: |
        set -euo pipefail
        firewall-cmd --permanent --zone=trusted --add-interface=br0
        firewall-cmd --permanent --zone=trusted --add-service=dhcp
        firewall-cmd --reload
    - shell: /bin/bash
    - onlyif: command -v firewall-cmd
    - onchanges:
      - file: vm_bridge_netdev
{% endif %}

{% if net.vpn_split_router %}
{% import_yaml 'data/vpn_split_router.yaml' as router %}

{{ ensure_dir('vpn_split_router_config_dir', home ~ '/.config/vpn-split-router', mode='0755') }}
{{ ensure_dir('vpn_split_router_state_dir', home ~ '/.local/state/vpn-split-router', mode='0755') }}

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
        router: {{ router | tojson }}

{{ user_service_file('vpn_split_router_service', 'vpn-split-router.service') }}
{{ user_service_file('vpn_split_router_timer', 'vpn-split-router.timer') }}

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
    - name: /etc/systemd/system/sing-box-tun-react.service
    - source: salt://units/sing-box-tun-react.service
    - mode: '0644'

sing_box_tun_react_path_unit:
  file.managed:
    - name: /etc/systemd/system/sing-box-tun-react.path
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

amnezia_import_tun_script:
  file.managed:
    - name: /usr/local/bin/amnezia-import-tun-config
    - source: salt://scripts/amnezia-import-tun-config.sh
    - mode: '0755'
    - user: root
    - group: root

amnezia_import_tun_user_script:
  file.symlink:
    - name: {{ home }}/.local/bin/amnezia-import-tun-config
    - target: /usr/local/bin/amnezia-import-tun-config
    - user: {{ user }}
    - group: {{ user }}
    - makedirs: True
    - require:
      - file: amnezia_import_tun_script

{{ user_service_file('amnezia_import_tun_user_service', 'amnezia-import-tun.service') }}
{% endif %}
