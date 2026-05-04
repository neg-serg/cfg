{# ════════════════════════════════════════════════════════════════════
   IPv6 6to4 tunnel — Phase 2a.
   Feature gate: features.network.ipv6_6to4
   Zero-config: auto-detects public IPv4 via cached file (1h TTL), no gopass secrets needed.
   Uses anycast relay at 192.88.99.1 (RFC 3068).
   ════════════════════════════════════════════════════════════════════ #}

{% from '_macros_service.jinja' import service_with_unit %}

{% set _ipv4_cache = '/var/cache/salt/public-ipv4.txt' %}
{% if salt['file.file_exists'](_ipv4_cache) %}
{% set _public_v4 = salt['file.read'](_ipv4_cache).strip() %}
{% else %}
{% set _public_v4 = '' %}
{% endif %}
{% set _has_v4 = (_public_v4 | length > 0) and (_public_v4.count('.') == 3) %}

# --- Compute 6to4 prefix ---
{% if _has_v4 %}
{% set _octets = _public_v4.split('.') %}
{% set _hex1 = '%02x' | format(_octets[0] | int) %}
{% set _hex2 = '%02x' | format(_octets[1] | int) %}
{% set _hex3 = '%02x' | format(_octets[2] | int) %}
{% set _hex4 = '%02x' | format(_octets[3] | int) %}
{% set _prefix6 = '2002:' ~ _hex1 ~ _hex2 ~ ':' ~ _hex3 ~ _hex4 %}
{% endif %}

# --- Tunnel interface ---
{% if _has_v4 %}
cache_public_v4:
  cmd.run:
    - name: curl -4 --max-time 3 --silent https://ifconfig.me | tee {{ _ipv4_cache }}
    - unless: test -f {{ _ipv4_cache }} && test $(find {{ _ipv4_cache }} -mmin -60 | wc -l) -gt 0

{{ service_with_unit('tun6to4', 'salt://states/units/tun6to4.service.j2', enabled=True, running=True, template='jinja', context={'public_v4': _public_v4, 'prefix6': _prefix6}, requires=['cmd: tun6to4_firewall_apply']) }}

tun6to4_firewall:
  file.managed:
    - name: /etc/nftables/6to4-tunnel.conf
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

tun6to4_firewall_apply:
  cmd.run:
    - name: |
        set -euo pipefail
        if command -v nft &>/dev/null; then
          nft -f /etc/nftables/6to4-tunnel.conf 2>/dev/null || { nft flush ruleset ipv6-tunnel 2>/dev/null || true; nft -f /etc/nftables/6to4-tunnel.conf; }
        fi
        if command -v ip6tables &>/dev/null; then
          ip6tables -I INPUT -i tun6to4 -p icmpv6 -j ACCEPT 2>/dev/null || true
          ip6tables -I FORWARD -i tun6to4 -p icmpv6 -j ACCEPT 2>/dev/null || true
          ip6tables -I INPUT -i tun6to4 -m state --state ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || true
          ip6tables -I FORWARD -i tun6to4 -m state --state ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || true
        fi
    - shell: /bin/bash
    - onchanges:
      - file: tun6to4_firewall
{% else %}
# 6to4 tunnel skip: could not detect public IPv4 address.
# Ensure outbound IPv4 connectivity to https://ifconfig.me — may be blocked by firewall or proxy.
{% endif %}
