# Jellyfin media server — pure Quadlet (Podman container).
{% from '_imports.jinja' import host %}
{% import_yaml 'data/service_catalog.yaml' as catalog %}
{% import_yaml 'data/container_images.yaml' as image_registry %}
{% from '_macros_service.jinja' import ensure_dir, remove_native_unit %}
{% from '_macros_container.jinja' import container_service %}

# Jellyfin media server — pure Quadlet (Podman container).
# Replaces native pacman packages (jellyfin-server, jellyfin-web).

{# In-place cutover: remove native systemd unit file so Quadlet-generated unit is not shadowed. #}
{{ remove_native_unit('jellyfin') }}

{# Config + cache directories on host — container bind-mounts need them to exist #}
{{ ensure_dir('jellyfin_config_dir', '/etc/jellyfin', mode='0755') }}
{{ ensure_dir('jellyfin_cache_dir', '/var/cache/jellyfin', mode='0755') }}

{{ container_service('jellyfin', catalog.jellyfin, image_registry,
    quadlet_unit_name='jellyfin-container',
    requires=['file: jellyfin_config_dir', 'file: jellyfin_cache_dir', 'cmd: jellyfin_native_unit_daemon_reload']) }}
