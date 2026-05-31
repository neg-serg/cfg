{#- @state
   id: network.awg_tunnel
   purpose: "AmneziaWG tunnel: deploys obfuscated AWG config with secrets from gopass, managed via systemd service."
   data_files: [data/awg_tunnel.yaml, data/packages.yaml]
   configs: [configs/awg-tunnel.conf.j2]
   scripts: [scripts/socks5-forward.py]
   services: [awg-tunnel.service, socks5-forward.service]
   feature_gate: [network.awg_tunnel]
#}
{% from '_imports.jinja' import host, user, home %}
{% import_yaml 'data/awg_tunnel.yaml' as awg %}
{% set net = host.features.network %}

{% if net.get('awg_tunnel', false) %}

socks5_forwarder_script:
  file.managed:
    - name: {{ home }}/.local/bin/socks5-forward
    - source: salt://scripts/socks5-forward.py
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0755'

awg_tunnel_config:
  file.managed:
    - name: {{ awg.config_path }}
    - source: salt://configs/awg-tunnel.conf.j2
    - template: jinja
    - user: root
    - group: root
    - mode: '0600'
    - context:
        awg: {{ awg | tojson }}
    - show_changes: False

awg_tunnel_service_unit:
  file.managed:
    - name: /etc/systemd/system/awg-tunnel.service
    - source: salt://units/awg-tunnel.service
    - template: jinja
    - user: root
    - group: root
    - mode: '0644'
    - context:
        config_path: {{ awg.config_path }}

awg_tunnel_daemon_reload:
  cmd.run:
    - name: systemctl daemon-reload
    - onchanges:
      - file: awg_tunnel_service_unit

awg_tunnel_running:
  service.running:
    - name: awg-tunnel
    - enable: True
    - require:
      - file: awg_tunnel_config
      - file: awg_tunnel_service_unit
      - cmd: awg_tunnel_daemon_reload

{{ salt['user_service.user_service_file']('socks5_forward_service', 'socks5-forward.service') }}

{{ salt['user_service.user_service_enable']('socks5_forward_enabled',
    start_now=['socks5-forward.service'],
    requires=[
        'file: socks5_forwarder_script',
        'file: socks5_forward_service',
        'cmd: socks5_forward_service_daemon_reload',
    ],
) }}

{% endif %}
