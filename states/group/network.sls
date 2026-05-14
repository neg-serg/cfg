{# Network group: VPN, firewall, DNS, IPv6 tunnels, and routing #}
{#- @state
   id: group.network
   purpose: "Network group: VPN, firewall, DNS, IPv6 tunnels, and routing."
   includes: [amnezia, dns, hiddify, ipv6, ipv6_6to4, ipv6_tunnel, network, zapret2]
   feature_gate: [amnezia, network.hiddify, network.ipv6, network.ipv6_6to4, network.ipv6_tunnel, network.zapret2]
#}
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
{% if host.features.get('amnezia', false) %}
  - amnezia
{% endif %}
{% if host.features.network.get('zapret2', false) %}
  - zapret2
{% endif %}
{% if host.features.network.get('hiddify', false) %}
  - hiddify
{% endif %}
