{% from '_imports.jinja' import host %}
{% set net = host.features.network %}

include:
  - network.vm_bridge
  - network.vpn_split_router
  - network.vpn_hybrid
