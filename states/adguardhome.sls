# =============================================================================
# AdGuard Home DNS filter — Quadlet container deployment
# =============================================================================
{% from '_imports.jinja' import host, user %}
{% import_yaml 'data/service_catalog.yaml' as catalog %}
{% import_yaml 'data/container_images.yaml' as image_registry %}
{% from '_macros_service.jinja' import ensure_dir, service_with_healthcheck, remove_native_unit %}
{% from '_macros_container.jinja' import container_service %}

# AdGuard Home DNS filter — pure Quadlet (Podman container).
# Replaces native pacman package (adguardhome) + custom systemd unit.
#
# Host-level integration that stays outside the container:
# - /etc/systemd/resolved.conf.d/adguardhome.conf (systemd-resolved redirect)

{# ── Cleanup legacy binary ── #}
adguardhome_legacy_cleanup:
  file.absent:
    - name: /usr/local/bin/AdGuardHome
    - onlyif: test -f /usr/local/bin/AdGuardHome

{{ remove_native_unit('adguardhome') }}

{# ── Work directory for container bind-mount ── #}
{{ ensure_dir('adguardhome_work_dir', '/var/lib/adguardhome-container/work', mode='0755', user='root') }}
{{ ensure_dir('adguardhome_conf_dir', '/var/lib/adguardhome-container/conf', mode='0755', user='root') }}

{# ── Initial config seed (replace: False — AdGuardHome rewrites it) ── #}
adguardhome_initial_config:
  file.managed:
    - name: /var/lib/adguardhome-container/conf/AdGuardHome.yaml
    - source: salt://configs/adguardhome-initial.yaml
    - user: root
    - group: root
    - mode: '0640'
    - replace: False
    - makedirs: True
    - require:
      - file: adguardhome_work_dir
      - file: adguardhome_conf_dir

{# ── systemd-resolved integration (host-level, stays outside container) ── #}
adguardhome_resolved_conf:
  file.managed:
    - name: /etc/systemd/resolved.conf.d/adguardhome.conf
    - source: salt://configs/resolved-adguardhome.conf
    - mode: '0644'
    - makedirs: True

systemd_resolved_restart_on_adguardhome_change:
  cmd.run:
    - name: systemctl restart systemd-resolved
    - onlyif: systemctl is-enabled systemd-resolved >/dev/null 2>&1
    - onchanges:
      - file: adguardhome_resolved_conf

{# ── Container deployment ── #}
{{ container_service('adguardhome', catalog.adguardhome, image_registry,
    quadlet_unit_name='adguardhome-container',
    requires=['file: adguardhome_work_dir', 'file: adguardhome_initial_config', 'cmd: adguardhome_native_unit_daemon_reload']) }}

{# ── Healthcheck ── #}
{{ service_with_healthcheck('adguardhome_start', 'adguardhome-container',
    catalog={'adguardhome-container': catalog.adguardhome},
    requires=['cmd: adguardhome_running']) }}
