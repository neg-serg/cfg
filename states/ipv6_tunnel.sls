
{% import_yaml 'data/ipv6.yaml' as ipv6_config %}

{# ════════════════════════════════════════════════════════════════════
   IPv6 HE.net tunnel (6in4) — Phase 2.
   Feature gate: features.network.ipv6_tunnel
   Requires: gopass api/he-tunnel with server_ipv4, client_ipv6, routed_prefix.
   ════════════════════════════════════════════════════════════════════ #}

{% set _he_secret = salt['secrets.get']('api/he-tunnel') %}
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

{% if _has_he %}
{%- set _svc_ctx = {
     'interface_name': _tun.interface_name,
     'server_ipv4': _he.server_ipv4,
     'client_ipv6': _he.client_ipv6,
     'client_ipv6_prefix': _he.client_ipv6.split("/")[0],
     'routed_prefix_base': _he.routed_prefix.split("/")[0],
     'routed_prefix_len': _he.routed_prefix.split("/")[1],
     'ttl': _tun.ttl
   } -%}
{%- set _sysctl_config -%}
net.ipv6.conf.{{ _tun.interface_name }}.disable_ipv6 = 0
net.ipv6.conf.default.accept_ra = {{ 1 if _tun.sysctl.accept_ra else 0 }}
net.ipv6.conf.default.autoconf = {{ 1 if _tun.sysctl.autoconf else 0 }}
{%- endset %}
{%- if _tun.ip6tables_enable -%}
{%- set _firewall_rules -%}
table inet ipv6-tunnel {
    chain input {
        icmpv6 type { nd-neighbor-solicit, nd-neighbor-advert, nd-router-solicit, nd-router-advert } accept
        icmpv6 type { destination-unreachable, packet-too-big, time-exceeded, parameter-problem } accept
    }
    chain forward {
        icmpv6 type { nd-neighbor-solicit, nd-neighbor-advert, nd-router-solicit, nd-router-advert } accept
    }
}
{%- endset %}
{%- else -%}
{%- set _firewall_rules = '' -%}
{%- endif %}

{{ salt['service.ipv6_tunnel'](
     name='he_tunnel',
     interface=_tun.interface_name,
     service_name='he-tunnel',
     service_template='salt://states/units/he-tunnel.service.j2',
     service_context=_svc_ctx,
     firewall_table='ipv6-tunnel',
     firewall_rules=_firewall_rules,
     sysctl_config=_sysctl_config
   ) }}
{% else %}
# HE tunnel skip: no api/he-tunnel secret found in gopass.
# Run: gopass insert api/he-tunnel  (with server_ipv4, client_ipv6, routed_prefix)
{% endif %}
