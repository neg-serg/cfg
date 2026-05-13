# =============================================================================
# DuckDNS dynamic DNS updater — Quadlet container deployment
# =============================================================================
{% from '_imports.jinja' import user %}

{% from '_macros_container.jinja' import container_service, catalog, image_registry %}

{{ salt['service.remove_native_unit']('duckdns_update_service', '/etc/systemd/system/duckdns-update.service') }}
{{ salt['service.remove_native_unit']('duckdns_update_timer', '/etc/systemd/system/duckdns-update.timer') }}

duckdns_native_script_absent:
  file.absent:
    - name: /usr/local/bin/duckdns-update

{{ salt['service.ensure_dir']('duckdns_env_dir', '/etc', mode='0755', user='root') }}

{{ container_service('duckdns', catalog.duckdns, image_registry,
    quadlet_unit_name='duckdns-update-container',
    requires=['cmd: duckdns_update_service_native_unit_daemon_reload']) }}
