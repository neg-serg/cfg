# =============================================================================
# System services — data-driven service management (network, DNS, monitoring)
# =============================================================================
{% from '_imports.jinja' import host, user, home %}
{% from '_macros_service.jinja' import ensure_dir, ensure_running, render_service, service_stopped, service_with_healthcheck, service_with_unit, unit_override %}
{% from '_macros_pkg.jinja' import paru_install, simple_service %}
{% import_yaml 'data/services.yaml' as services %}

{% set svc = host.features.services %}
{% set net = host.features.network %}
{% set dns = host.features.dns %}
{% set mon = host.features.monitoring %}

# ===================================================================
# Simple services (data-driven: paru install + service enable)
# ===================================================================

{% for name, opts in services.simple.items() %}
{% if svc.get(name, False) %}
{{ simple_service(name, opts.packages, service=opts.service) }}
{% endif %}
{% endfor %}

# ===================================================================
# Orchestrated services (complex, network, dns — shared template)
# ===================================================================

{% set known_vars = {
    'hostname': host.hostname,
    'mnt_zero': host.mnt_zero,
    'mnt_one': host.mnt_one,
    'user': user,
    'home': home,
    'vpn_split_router': net.get('vpn_split_router', False),
    'dns_unbound': dns.get('unbound', False),
} %}

{# ── Complex services ── #}
{% for name, opts in services.get('complex', {}).items() %}
{{ render_service(name, opts, svc.get(name, False), 'complex', known_vars=known_vars) }}
{% endfor %}

{# ── Network services ── #}
{% for name, opts in services.get('network', {}).items() %}
{{ render_service(name, opts, net.get(name, False), 'network', known_vars=known_vars) }}
{% endfor %}

{# ── DNS services ── #}
{% for name, opts in services.get('dns', {}).items() %}
{{ render_service(name, opts, dns.get(name, False), 'dns', known_vars=known_vars) }}
{% endfor %}

# ===================================================================
# Monitoring services (merged from monitoring.sls)
# ===================================================================

{% if mon.sysstat %}
{{ simple_service('sysstat', 'sysstat') }}
{% endif %}

{% if mon.vnstat %}
{{ simple_service('vnstat', 'vnstat') }}
{% endif %}

{% if mon.netdata %}
{{ unit_override('netdata_override', 'netdata.service', 'salt://units/netdata-override.conf') }}
{% endif %}
