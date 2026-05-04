{% from '_imports.jinja' import gopass_secret %}
{% from '_macros_service.jinja' import service_with_unit %}
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
{{ service_with_unit('he-tunnel', 'salt://states/units/he-tunnel.service.j2', enabled=True, running=True, template='jinja', context={'interface_name': _tun.interface_name, 'server_ipv4': _he.server_ipv4, 'client_ipv6': _he.client_ipv6, 'client_ipv6_prefix': _he.client_ipv6.split("/")[0], 'routed_prefix_base': _he.routed_prefix.split("/")[0], 'routed_prefix_len': _he.routed_prefix.split("/")[1], 'ttl': _tun.ttl}, watch=['file: he_tunnel_sysctl']) }}

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

{% else %}
# HE tunnel skip: no api/he-tunnel secret found in gopass.
# Run: gopass insert api/he-tunnel  (with server_ipv4, client_ipv6, routed_prefix)
{% endif %}
