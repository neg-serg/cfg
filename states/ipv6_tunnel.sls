{% from '_imports.jinja' import host, user, home, gopass_secret %}
{% import_yaml 'data/ipv6.yaml' as ipv6_config %}

{# ════════════════════════════════════════════════════════════════════
   IPv6 HE.net tunnel (6in4) — Phase 2.
   Feature gate: features.network.ipv6_tunnel
   Requires: gopass api/he-tunnel with server_ipv4, client_ipv6, routed_prefix.
   ════════════════════════════════════════════════════════════════════ #}

{% set _he_secret = gopass_secret('api/he-tunnel') %}
{% set _has_he = _he_secret | length > 0 %}

{% if _has_he %}
{% set _he = {} %}
{% for _line in _he_secret.split('\n') %}
  {% if '=' in _line %}
    {% set _kv = _line.split('=', 1) %}
    {% do _he.update({_kv[0].strip(): _kv[1].strip()}) %}
  {% endif %}
{% endfor %}
{% endif %}

{% set _tun = ipv6_config.tunnel %}

# ── Tunnel interface systemd service ──────────────────────────────

{% if _has_he %}
he_tunnel_service:
  file.managed:
    - name: /etc/systemd/system/he-tunnel.service
    - mode: '0644'
    - contents: |
        [Unit]
        Description=HE.net IPv6 tunnel (6in4)
        After=network-online.target
        Wants=network-online.target

        [Service]
        Type=oneshot
        RemainAfterExit=yes
        ExecStart=/bin/sh -c '\
          ip tunnel add {{ _tun.interface_name }} mode sit remote {{ _he.server_ipv4 }} local any ttl {{ _tun.ttl }} && \
          ip link set {{ _tun.interface_name }} up && \
          ip addr add {{ _he.client_ipv6 }} dev {{ _tun.interface_name }} && \
          ip -6 route add default via {{ _he.client_ipv6.split("/")[0] }} dev {{ _tun.interface_name }} || \
          ip addr add {{ _he.routed_prefix.split("/")[0] }}1/{{ _he.routed_prefix.split("/")[1] }} dev {{ _tun.interface_name }}'
        ExecStop=/bin/sh -c '\
          ip -6 route del default via {{ _he.client_ipv6.split("/")[0] }} dev {{ _tun.interface_name }} 2>/dev/null || true; \
          ip link set {{ _tun.interface_name }} down 2>/dev/null || true; \
          ip tunnel del {{ _tun.interface_name }} 2>/dev/null || true'

        [Install]
        WantedBy=multi-user.target

he_tunnel_sysctl:
  file.managed:
    - name: /etc/sysctl.d/99-ipv6-tunnel.conf
    - mode: '0644'
    - contents: |
        net.ipv6.conf.{{ _tun.interface_name }}.disable_ipv6 = 0
        net.ipv6.conf.default.accept_ra = {{ 1 if _tun.sysctl.accept_ra else 0 }}
        net.ipv6.conf.default.autoconf = {{ 1 if _tun.sysctl.autoconf else 0 }}

  cmd.run:
    - name: sysctl --system
    - onchanges:
      - file: he_tunnel_sysctl

{% if _tun.ip6tables_enable %}
he_tunnel_firewall:
  file.managed:
    - name: /etc/nftables/ipv6-tunnel.conf
    - mode: '0644'
    - makedirs: True
    - contents: |
        table inet ipv6-tunnel {
            chain input {
                icmpv6 type { nd-neighbor-solicit, nd-neighbor-advert, nd-router-solicit, nd-router-advert } accept
                icmpv6 type { destination-unreachable, packet-too-big, time-exceeded, parameter-problem } accept
            }
            chain forward {
                icmpv6 type { nd-neighbor-solicit, nd-neighbor-advert, nd-router-solicit, nd-router-advert } accept
            }
        }

he_tunnel_firewall_apply:
  cmd.run:
    - name: |
        set -euo pipefail
        if command -v nft &>/dev/null; then
          nft -f /etc/nftables/ipv6-tunnel.conf 2>/dev/null || nft flush ruleset ipv6-tunnel && nft -f /etc/nftables/ipv6-tunnel.conf
        elif command -v ip6tables &>/dev/null; then
          ip6tables -I INPUT -i {{ _tun.interface_name }} -p icmpv6 -j ACCEPT
          ip6tables -I FORWARD -i {{ _tun.interface_name }} -p icmpv6 -j ACCEPT
          ip6tables -I INPUT -i {{ _tun.interface_name }} -m state --state ESTABLISHED,RELATED -j ACCEPT
          ip6tables -I FORWARD -i {{ _tun.interface_name }} -m state --state ESTABLISHED,RELATED -j ACCEPT
        fi
    - shell: /bin/bash
    - onchanges:
      - file: he_tunnel_firewall
{% endif %}

# ── Enable and start tunnel ───────────────────────────────────────

he_tunnel_daemon_reload:
  cmd.run:
    - name: systemctl daemon-reload
    - onchanges:
      - file: he_tunnel_service

he_tunnel_enable:
  cmd.run:
    - name: systemctl enable he-tunnel.service
    - unless: systemctl is-enabled he-tunnel.service 2>/dev/null
    - require:
      - file: he_tunnel_service
      - cmd: he_tunnel_daemon_reload

he_tunnel_start:
  cmd.run:
    - name: systemctl restart he-tunnel.service
    - onlyif: systemctl is-active he-tunnel.service 2>/dev/null || true
    - onchanges:
      - file: he_tunnel_service
      - file: he_tunnel_sysctl
    - require:
      - cmd: he_tunnel_daemon_reload
{% else %}
# HE tunnel skip: no api/he-tunnel secret found in gopass.
# Run: gopass insert api/he-tunnel  (with server_ipv4, client_ipv6, routed_prefix)
{% endif %}
