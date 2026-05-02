{% from '_imports.jinja' import host, user, home %}
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

ipv6_healthcheck_service:
  file.managed:
    - name: /etc/systemd/system/check-ipv6.service
    - mode: '0644'
    - contents: |
        [Unit]
        Description=IPv6 health check
        After=network-online.target
        Wants=network-online.target

        [Service]
        Type=oneshot
        ExecStart=/usr/local/bin/check-ipv6.sh
        StandardOutput=journal

ipv6_healthcheck_timer:
  file.managed:
    - name: /etc/systemd/system/check-ipv6.timer
    - mode: '0644'
    - contents: |
        [Unit]
        Description=Daily IPv6 health check
        Requires=check-ipv6.service

        [Timer]
        OnCalendar={{ ipv6_config.diagnostics.timer.on_calendar }}
        RandomizedDelaySec={{ ipv6_config.diagnostics.timer.get('randomized_delay_sec', 600) }}
        Persistent=true

        [Install]
        WantedBy=timers.target

ipv6_healthcheck_daemon_reload:
  cmd.run:
    - name: systemctl daemon-reload
    - onchanges:
      - file: ipv6_healthcheck_service
      - file: ipv6_healthcheck_timer

enable_ipv6_healthcheck_timer:
  cmd.run:
    - name: systemctl enable --now check-ipv6.timer
    - unless: systemctl is-enabled check-ipv6.timer 2>/dev/null
    - require:
      - file: ipv6_healthcheck_timer
      - cmd: ipv6_healthcheck_daemon_reload
{% endif %}
