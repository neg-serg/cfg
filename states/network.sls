{% from '_imports.jinja' import host, home, user %}
{% from '_macros_service.jinja' import user_service_file %}
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
