{# Amnezia VPN: builds AmneziaWG kernel module and Amnezia VPN desktop client from source. #}
{% from '_imports.jinja' import host, user, home, retry_attempts, retry_interval %}
{% from '_macros_service.jinja' import ensure_dir, service_with_unit %}
{% import_yaml 'data/versions.yaml' as ver %}
{% import_yaml 'data/amnezia.yaml' as amnezia %}
{% set cache = host.mnt_one ~ '/pkg/cache/amnezia' %}

{{ ensure_dir('amnezia_cache_dir', cache, require=['mount: mount_one']) }}

{% set _amnezia_ver = ver.get('amnezia_vpn', '') %}
{% set _amnezia_ver_marker = '/var/cache/salt/versions/amnezia_vpn@' ~ _amnezia_ver if _amnezia_ver else '' %}
amnezia_build:
  cmd.script:
    - source: salt://scripts/amnezia-build.sh
    - shell: /bin/bash
    - timeout: 3600
    - output_loglevel: info
    - env:
      - BUILD: {{ cache }}
      - AMNEZIA_VERSION: {{ _amnezia_ver }}
    - unless: >-
{%- if _amnezia_ver %}
        test -f {{ _amnezia_ver_marker }} &&
{%- endif %}
        test -f {{ cache }}/amneziawg-go-bin &&
        test -f {{ cache }}/awg-bin &&
        test -f {{ cache }}/AmneziaVPN-bin &&
        test -f {{ cache }}/AmneziaVPN-service-bin
    - retry:
        attempts: {{ retry_attempts }}
        interval: {{ retry_interval }}
    - require:
      - file: amnezia_cache_dir

{% if _amnezia_ver %}
amnezia_version_stamp:
  cmd.run:
    - name: mkdir -p /var/cache/salt/versions && rm -f /var/cache/salt/versions/amnezia_vpn@* && touch {{ _amnezia_ver_marker }}
    - onlyif: test -x {{ cache }}/amneziawg-go-bin && test -x {{ cache }}/awg-bin && test -x {{ cache }}/AmneziaVPN-bin && test -x {{ cache }}/AmneziaVPN-service-bin
    - onchanges:
      - cmd: amnezia_build
{% endif %}

{% for state_id, cfg in amnezia.bins.items() %}
{{ state_id }}:
  file.managed:
    - name: /usr/local/bin/{{ cfg.dest }}
    - source: {{ cache }}/{{ cfg.src }}
    - mode: '0755'
    - user: root
    - group: root
    - require:
      - cmd: amnezia_build
{% endfor %}

{% for state_id, cmd, bin_state, binary_path in [
  ('amneziawg_go', amnezia.verification.amneziawg_go, 'amneziawg_go_bin', '/usr/local/bin/amneziawg-go'),
  ('awg', amnezia.verification.awg, 'amneziawg_tools_bin', '/usr/local/bin/awg'),
  ('amnezia_vpn', amnezia.verification.amnezia_vpn, 'amnezia_vpn_bin', '/usr/local/bin/AmneziaVPN'),
  ('amnezia_service', amnezia.verification.amnezia_service, 'amnezia_service_bin', '/usr/local/bin/AmneziaVPN-service'),
] %}
{{ state_id }}_verify:
  cmd.run:
    - name: {{ cmd }}
    - onlyif: test -x {{ binary_path }}
    - onchanges:
      - file: {{ bin_state }}
{% endfor %}

{{ service_with_unit('AmneziaVPN-source', 'salt://units/amnezia-vpn-source.service', enabled=True, requires=['file: amnezia_service_bin']) }}

{{ ensure_dir('amnezia_apps_dir', home ~ '/.local/share/applications') }}

amnezia_desktop_entry:
  file.managed:
    - name: {{ home }}/.local/share/applications/{{ amnezia.desktop_entry }}
    - contents: |
        [Desktop Entry]
        Type=Application
        Name=AmneziaVPN (Source)
        Comment=Amnezia VPN Client (Self-built)
        Exec=/usr/local/bin/AmneziaVPN
        Icon=amnezia-vpn
        Terminal=false
        Categories=Network;VPN;
    - user: {{ user }}
    - group: {{ user }}
    - require:
      - file: amnezia_apps_dir
