{% from '_imports.jinja' import home %}




{% import_yaml 'data/service_catalog.yaml' as catalog %}

{% import_yaml 'data/container_images.yaml' as image_registry %}
# Transmission BitTorrent client — pure Quadlet (Podman container).
# Replaces native pacman package (transmission-cli) + escape hatch logic.
#
# ACLs and config replacement are no longer needed:
# - ACLs were for granting 'transmission' user access to ~/dw and ~/torrent/data
#   → replaced by bind mounts (container runs as USER_UID/USER_GID)
# - config replacement (sed on settings.json) was for download-dir/watch-dir
#   → replaced by bind mount paths + linuxserver env vars

{# In-place cutover: remove native systemd unit so Quadlet-generated unit is not shadowed. #}
{{ salt['service.remove_native_unit']('transmission') }}

{{ salt['service.service_stopped']('transmission_native_service_disabled', 'transmission', requires=['cmd: transmission_native_unit_daemon_reload']) }}

{# Directories that will be bind-mounted into the container #}
{{ salt['service.ensure_dir']('transmission_config_dir', '/etc/transmission', mode='0755') }}
{{ salt['service.ensure_dir']('transmission_watch_dir', home ~ '/dw', mode='0755') }}
{{ salt['service.ensure_dir']('transmission_download_dir', home ~ '/torrent/data', mode='0755') }}

{{ salt['container.deploy']('transmission', catalog.transmission, image_registry,
    quadlet_unit_name='transmission-container',
    requires=['file: transmission_config_dir', 'file: transmission_watch_dir', 'file: transmission_download_dir', 'cmd: transmission_native_unit_daemon_reload', 'service: transmission_native_service_disabled']) }}
