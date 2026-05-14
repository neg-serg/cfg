{# ════════════════════════════════════════════════════════════════════
   IPv6 6to4 tunnel — Phase 2a.
   Feature gate: features.network.ipv6_6to4
   Zero-config: auto-detects public IPv4 via cached file (1h TTL), no gopass secrets needed.
   Uses anycast relay at 192.88.99.1 (RFC 3068).
   ════════════════════════════════════════════════════════════════════ #}
{#- @state
   id: ipv6_6to4
   purpose: ""
   data_files: [data/vpn.yaml]
#}

{% import_yaml 'data/vpn.yaml' as vpn %}

{% set _ipv4_cache = vpn.ipv6_6to4.cache_path %}
{% if salt['file.file_exists'](_ipv4_cache) %}
{% set _public_v4 = salt['file.read'](_ipv4_cache).strip() %}
{% else %}
{% set _public_v4 = '' %}
{% endif %}
{% set _has_v4 = (_public_v4 | length > 0) and (_public_v4.count('.') == 3) %}

{% if _has_v4 %}
{% set _octets = _public_v4.split('.') %}
{% set _hex1 = '%02x' | format(_octets[0] | int) %}
{% set _hex2 = '%02x' | format(_octets[1] | int) %}
{% set _hex3 = '%02x' | format(_octets[2] | int) %}
{% set _hex4 = '%02x' | format(_octets[3] | int) %}
{% set _prefix6 = '2002:' ~ _hex1 ~ _hex2 ~ ':' ~ _hex3 ~ _hex4 %}
{%- set _firewall_rules -%}
table inet 6to4-tunnel {
    chain input {
        icmpv6 type { nd-neighbor-solicit, nd-neighbor-advert, nd-router-solicit, nd-router-advert } accept
        icmpv6 type { destination-unreachable, packet-too-big, time-exceeded, parameter-problem } accept
    }
    chain forward {
        icmpv6 type { nd-neighbor-solicit, nd-neighbor-advert, nd-router-solicit, nd-router-advert } accept
    }
}
{%- endset %}

cache_public_v4:
  cmd.run:
    - name: curl -4 --max-time 3 --silent {{ vpn.ipv6_6to4.public_ip_url }} | tee {{ _ipv4_cache }}
    - unless: test -f {{ _ipv4_cache }} && test $(find {{ _ipv4_cache }} -mmin -60 | wc -l) -gt 0

{{ salt['ipv6_tunnel.deploy'](
     name='tun6to4',
     interface='tun6to4',
     service_name='tun6to4',
     service_template='salt://states/units/tun6to4.service.j2',
     service_context={'public_v4': _public_v4, 'prefix6': _prefix6},
     firewall_table='6to4-tunnel',
     firewall_rules=_firewall_rules
   ) }}
{% else %}
# 6to4 tunnel skip: could not detect public IPv4 address.
# Ensure outbound IPv4 connectivity to {{ vpn.ipv6_6to4.public_ip_url }} — may be blocked by firewall or proxy.
{% endif %}
