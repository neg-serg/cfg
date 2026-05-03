{# Network group: VPN, firewall, DNS, IPv6 tunnels, and routing #}
# Group: network and DNS
# Usage: just apply group/network

{% from '_imports.jinja' import host %}

include:
  - dns
  - network
{% if host.features.network.get('ipv6', false) %}
  - ipv6
{% endif %}
{% if host.features.network.get('ipv6_6to4', false) %}
  - ipv6_6to4
{% endif %}
{% if host.features.network.get('ipv6_tunnel', false) %}
  - ipv6_tunnel
{% endif %}
