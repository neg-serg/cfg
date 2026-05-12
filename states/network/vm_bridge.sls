{% from '_imports.jinja' import host %}
{% import_yaml 'data/network.yaml' as network %}
{% set net = host.features.network %}

{% if net.vm_bridge %}
{% set br = network.vm_bridge %}
vm_bridge_netdev:
  file.managed:
    - name: {{ br.netdev }}
    - makedirs: True
    - mode: '0644'
    - contents: |
        [NetDev]
        Name={{ br.name }}
        Kind={{ br.kind }}

vm_bridge_network:
  file.managed:
    - name: {{ br.network }}
    - makedirs: True
    - mode: '0644'
    - source: salt://configs/br0.network

vm_bridge_firewall:
  cmd.run:
    - name: |
        set -euo pipefail
        firewall-cmd --permanent --zone=trusted --add-interface={{ br.name }}
        firewall-cmd --permanent --zone=trusted --add-service=dhcp
        firewall-cmd --reload
    - shell: /bin/bash
    - onlyif: command -v firewall-cmd
    - onchanges:
      - file: vm_bridge_netdev
{% endif %}
