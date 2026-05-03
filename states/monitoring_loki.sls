# Loki + Promtail + Grafana monitoring stack — pure Quadlet (Podman containers).
# All three services run exclusively as containers; native packages stay
# installed for /etc/ directory structure and provisioning files.
{% from '_imports.jinja' import host %}
{% import_yaml 'data/service_catalog.yaml' as catalog %}
{% import_yaml 'data/container_images.yaml' as image_registry %}
{% from '_macros_service.jinja' import ensure_dir, container_service, remove_native_unit %}

{% set mon = host.features.monitoring %}

{# ── Loki: log aggregation ── #}


loki_config:
  file.managed:
    - name: /etc/loki/config.yaml
    - makedirs: True
    - mode: '0644'
    - source: salt://configs/loki.yaml.j2
    - template: jinja
    - context:
        loki_port: {{ catalog.loki.port }}



{{ ensure_dir('loki_container_state_dir', '/var/lib/loki-container', user='loki') }}

# In-place cutover: remove native systemd unit so Quadlet-generated unit is not shadowed.
{{ remove_native_unit('loki') }}

# Remove native package (idempotent — no-op if already removed)
loki_native_package_removed:
  pkg.removed:
    - pkgs:
      - loki

{{ container_service('loki', catalog.loki, image_registry,
    quadlet_unit_name='loki-container',
    requires=['file: loki_config', 'file: loki_container_state_dir', 'cmd: loki_native_unit_daemon_reload']) }}

{# ── Promtail: log shipper to Loki ── #}
{% if mon.promtail and mon.loki %}


promtail_config:
  file.managed:
    - name: /etc/promtail/config.yaml
    - makedirs: True
    - mode: '0644'
    - source: salt://configs/promtail.yaml.j2
    - template: jinja
    - context:
        loki_port: {{ catalog.loki.port }}
        promtail_port: {{ catalog.promtail.port }}



{{ ensure_dir('promtail_cache_dir', '/var/cache/promtail', user='promtail') }}

# In-place cutover: remove the native systemd unit file so the
# Quadlet-generated unit is no longer shadowed by the pacman-deployed
# /etc/systemd/system/promtail.service.
promtail_native_unit_absent:
  file.absent:
    - name: /etc/systemd/system/promtail.service

promtail_native_unit_daemon_reload:
  cmd.run:
    - name: systemctl daemon-reload
    - onlyif: test -e /run/systemd/system || test -e /etc/systemd/system
    - onchanges:
      - file: promtail_native_unit_absent

# Remove native package (idempotent — no-op if already removed)
promtail_native_package_removed:
  pkg.removed:
    - pkgs:
      - promtail

{{ container_service('promtail', catalog.promtail, image_registry,
    quadlet_unit_name='promtail-container',
    requires=['file: promtail_config', 'cmd: promtail_native_unit_daemon_reload']) }}
{% endif %}

{# ── Grafana: dashboard with Loki datasource ── #}
{% if mon.grafana %}


{% if mon.loki %}
grafana_loki_datasource:
  file.managed:
    - name: /etc/grafana/provisioning/datasources/loki.yaml
    - makedirs: True
    - mode: '0644'
    - source: salt://configs/grafana-loki-datasource.yaml.j2
    - template: jinja
    - context:
        loki_port: {{ catalog.loki.port }}
{% endif %}

grafana_config:
  file.managed:
    - name: /etc/grafana.ini
    - mode: '0644'
    - source: salt://configs/grafana.ini.j2
    - template: jinja
    - context:
        hostname: {{ host.hostname }}
        grafana_port: {{ catalog.grafana.port }}

grafana_dashboards_provider:
  file.managed:
    - name: /etc/grafana/provisioning/dashboards/dashboards.yaml
    - makedirs: True
    - mode: '0644'
    - source: salt://configs/grafana-dashboards-provider.yaml

grafana_proxypilot_dashboard:
  file.managed:
    - name: /etc/grafana/provisioning/dashboards/json/proxypilot.json
    - makedirs: True
    - mode: '0644'
    - source: salt://configs/grafana-dashboard-proxypilot.json



{{ ensure_dir('grafana_container_state_dir', '/var/lib/grafana-container', user='grafana', mode='0755') }}

# In-place cutover: remove the native systemd unit file so the
# Quadlet-generated unit is no longer shadowed by the pacman-deployed
# /etc/systemd/system/grafana.service.
grafana_native_unit_absent:
  file.absent:
    - name: /etc/systemd/system/grafana.service

grafana_native_unit_daemon_reload:
  cmd.run:
    - name: systemctl daemon-reload
    - onlyif: test -e /run/systemd/system || test -e /etc/systemd/system
    - onchanges:
      - file: grafana_native_unit_absent

# Remove native package (idempotent — no-op if already removed)
grafana_native_package_removed:
  pkg.removed:
    - pkgs:
      - grafana

{% set _grafana_watch = ['file: grafana_config', 'file: grafana_dashboards_provider', 'file: grafana_proxypilot_dashboard'] + (['file: grafana_loki_datasource'] if mon.loki else []) %}
{{ container_service('grafana', catalog.grafana, image_registry,
    quadlet_unit_name='grafana-container',
    requires=['file: grafana_config', 'file: grafana_dashboards_provider', 'file: grafana_proxypilot_dashboard', 'file: grafana_container_state_dir', 'cmd: grafana_native_unit_daemon_reload'],
    watch=_grafana_watch) }}
{% endif %}
