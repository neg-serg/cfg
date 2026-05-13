# =============================================================================
# Bitcoin Core daemon — Quadlet container deployment
# =============================================================================
{% from '_imports.jinja' import user %}

{% from '_macros_container.jinja' import container_service, catalog, image_registry %}

# Bitcoin Core daemon — pure Quadlet (Podman container).
# Replaces native pacman package (bitcoin-daemon) + custom systemd unit.
# Service is manual_start — Salt deploys but does not auto-start.

{{ salt['service.remove_native_unit']('bitcoind') }}

{# Data directory for blockchain state #}
{{ salt['service.ensure_dir']('bitcoind_data_dir', '/var/lib/bitcoind-container', mode='0755', user='root') }}

{{ container_service('bitcoind', catalog.bitcoind, image_registry,
    quadlet_unit_name='bitcoind-container',
    requires=['file: bitcoind_data_dir', 'cmd: bitcoind_native_unit_daemon_reload']) }}
