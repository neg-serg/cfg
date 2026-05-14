{#- @state
   id: jellyfin
   purpose: "In-place cutover: remove native systemd unit file so Quadlet-generated unit is not shadowed."
   services: [jellyfin.container]
#}
# Jellyfin media server — pure Quadlet (Podman container).
{% from '_imports.jinja' import host %}

# Jellyfin media server — pure Quadlet (Podman container).
# Replaces native pacman packages (jellyfin-server, jellyfin-web).

{# In-place cutover: remove native systemd unit file so Quadlet-generated unit is not shadowed. #}
{{ salt['service.remove_native_unit']('jellyfin') }}

{# Config + cache directories on host — container bind-mounts need them to exist #}
{{ salt['service.ensure_dir']('jellyfin_config_dir', '/etc/jellyfin', mode='0755') }}
{{ salt['service.ensure_dir']('jellyfin_cache_dir', '/var/cache/jellyfin', mode='0755') }}

{{ salt['container.deploy']('jellyfin',
    quadlet_unit_name='jellyfin-container',
    requires=['file: jellyfin_config_dir', 'file: jellyfin_cache_dir', 'cmd: jellyfin_native_unit_daemon_reload']) }}
