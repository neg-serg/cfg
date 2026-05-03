# =============================================================================
# Bitcoin Core daemon — Quadlet container deployment
# =============================================================================
{% from '_imports.jinja' import user %}
{% import_yaml 'data/service_catalog.yaml' as catalog %}
{% import_yaml 'data/container_images.yaml' as image_registry %}
{% from '_macros_service.jinja' import ensure_dir, container_service, remove_native_unit %}

# Bitcoin Core daemon — pure Quadlet (Podman container).
# Replaces native pacman package (bitcoin-daemon) + custom systemd unit.
# Service is manual_start — Salt deploys but does not auto-start.

{{ remove_native_unit('bitcoind') }}

{# Data directory for blockchain state #}
{{ ensure_dir('bitcoind_data_dir', '/var/lib/bitcoind-container', mode='0755', user='root') }}

{{ container_service('bitcoind', catalog.bitcoind, image_registry,
    quadlet_unit_name='bitcoind-container',
    requires=['file: bitcoind_data_dir', 'cmd: bitcoind_native_unit_daemon_reload']) }}
