# =============================================================================
# System services — data-driven service management (network, DNS, monitoring)
# =============================================================================
include:
  - pacman_db_warmup

{% from '_imports.jinja' import host, user, home %}
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
{{ salt['pkg.simple_service'](name, opts.packages, service=opts.service) }}
{% endif %}
{% endfor %}

# ===================================================================
# Orchestrated services (complex, network, dns — shared template)
# ===================================================================

{# ── Complex services ── #}
{% for name, opts in services.get('complex', {}).items() %}
{{ salt['service.render_service'](name, opts, svc.get(name, False), 'complex', host=host) }}
{% endfor %}

{# ── Network services ── #}
{% for name, opts in services.get('network', {}).items() %}
{{ salt['service.render_service'](name, opts, net.get(name, False), 'network', host=host) }}
{% endfor %}

{# ── DNS services ── #}
{% for name, opts in services.get('dns', {}).items() %}
{{ salt['service.render_service'](name, opts, dns.get(name, False), 'dns', host=host) }}
{% endfor %}

# ===================================================================
# Monitoring services (merged from monitoring.sls)
# ===================================================================

{% if mon.sysstat %}
{{ salt['pkg.simple_service']('sysstat', 'sysstat') }}
{% endif %}

{% if mon.vnstat %}
{{ salt['pkg.simple_service']('vnstat', 'vnstat') }}
{% endif %}

{% if mon.netdata %}
{{ salt['service.unit_override']('netdata_override', 'netdata.service', 'salt://units/netdata-override.conf') }}
{% endif %}
