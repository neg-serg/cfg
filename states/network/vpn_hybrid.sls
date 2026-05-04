{% from '_imports.jinja' import host, home, user %}
{% from '_macros_service.jinja' import ensure_dir %}
{% set net = host.features.network %}

{% if net.vpn_hybrid %}

{{ ensure_dir('sing_box_tun_hybrid_config_dir', home ~ '/.config/sing-box-tun', mode='0755') }}

sing_box_tun_hybrid_config:
  file.managed:
    - name: {{ home }}/.config/sing-box-tun/hybrid-config.json
    - source: salt://configs/sing-box-hybrid-config.json.j2
    - template: jinja
    - mode: '0644'
    - user: {{ user }}
    - group: {{ user }}
    - makedirs: True
    - context:
        ipv6_dns_strategy: {{ 'prefer_ipv4' if net.get('ipv6_tunnel', false) or net.get('ipv6_6to4', false) else 'ipv4_only' }}

sing_box_tun_hybrid_service_unit:
  file.managed:
    - name: /etc/systemd/system/sing-box-tun-hybrid.service
    - source: salt://units/sing-box-tun-hybrid.service
    - template: jinja
    - mode: '0644'
    - context:
        home: {{ home }}

sing_box_tun_hybrid_daemon_reload:
  cmd.run:
    - name: systemctl daemon-reload
    - onlyif: test -e /run/systemd/system || test -e /etc/systemd/system
    - onchanges:
      - file: sing_box_tun_hybrid_service_unit

xray_hybrid_config:
  file.managed:
    - name: /etc/xray/config.json
    - source: {{ home }}/.config/sing-box-tun/config.json
    - user: root
    - group: root
    - mode: '0644'
    - makedirs: True
    - onlyif: test -f {{ home }}/.config/sing-box-tun/config.json
    - require:
      - file: sing_box_tun_hybrid_config_dir

{% endif %}
