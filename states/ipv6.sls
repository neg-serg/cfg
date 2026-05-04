{# IPv6 diagnostics: connectivity check, firewall rules, and health monitoring #}
{% from '_imports.jinja' import user %}
{% from '_macros_service.jinja' import service_with_unit %}
{% import_yaml 'data/ipv6.yaml' as ipv6_config %}

# IPv6 diagnostics — deploys check-ipv6.sh script and optional timer.
# Feature gate: features.network.ipv6

ipv6_diagnostic_script:
  file.managed:
    - name: /usr/local/bin/check-ipv6.sh
    - source: salt://scripts/check-ipv6.sh
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0755'
    - makedirs: True

# Optional: systemd timer for periodic IPv6 health checks.
{% if ipv6_config.diagnostics.timer.get('on_calendar') %}

{{ service_with_unit('check-ipv6', 'salt://states/units/check-ipv6.timer.j2', unit_type='timer', enabled=True, running=True, template='jinja', context={'on_calendar': ipv6_config.diagnostics.timer.on_calendar, 'randomized_delay_sec': ipv6_config.diagnostics.timer.get('randomized_delay_sec', 600)}, companion='salt://states/units/check-ipv6.service') }}
{% endif %}
