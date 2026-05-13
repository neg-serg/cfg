{# Vaultwarden Bitwarden server: Quadlet container, backup timers, and bw-sync #}
# Vaultwarden password manager — Podman Quadlet container + Bitwarden CLI.
include:
  - pacman_db_warmup

{% from '_imports.jinja' import user, home %}
{% from '_macros_pkg.jinja' import paru_install %}

{% from '_macros_service_user.jinja' import user_service_file, user_service_enable %}
{% from '_macros_container.jinja' import container_service, catalog, image_registry %}

# AUR package for Bitwarden CLI
{{ paru_install('bitwarden_cli', 'bitwarden-cli') }}

# Sync and backup scripts in ~/.local/bin
bw_sync_script_dir:
  file.directory:
    - name: {{ home }}/.local/bin
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0755'

bw_sync_script:
  file.managed:
    - name: {{ home }}/.local/bin/bw-sync
    - source: salt://scripts/bw-sync.py
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0755'
    - require:
      - file: bw_sync_script_dir

vault_full_backup_script:
  file.managed:
    - name: {{ home }}/.local/bin/vault-full-backup
    - source: salt://scripts/vault-full-backup.sh
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0755'
    - require:
      - file: bw_sync_script_dir

# Host data directory for Vaultwarden SQLite
{{ salt['service.ensure_dir']('vaultwarden_data_dir', '/var/lib/vaultwarden', mode='0700') }}

# Podman Quadlet container
{{ container_service('vaultwarden', catalog.vaultwarden, image_registry,
    quadlet_unit_name='vaultwarden-container',
    requires=['file: vaultwarden_data_dir']) }}

# ─── User units (bw-sync — hourly Vaultwarden ↔ gopass sync) ───
{{ user_service_file('bw_sync_service', 'bw-sync.service') }}
{{ user_service_file('bw_sync_timer', 'bw-sync.timer') }}
{{ user_service_enable('bw_sync_enabled',
    start_now=['bw-sync.timer'],
    requires=[
        'file: bw_sync_service',
        'cmd: bw_sync_service_daemon_reload',
        'file: bw_sync_timer',
        'cmd: bw_sync_timer_daemon_reload',
    ],
) }}

# ─── User units (vault-full-backup — daily age-encrypted archive) ───
{{ user_service_file('vault_full_backup_service', 'vault-full-backup.service') }}
{{ user_service_file('vault_full_backup_timer', 'vault-full-backup.timer') }}
{{ user_service_enable('vault_full_backup_enabled',
    start_now=['vault-full-backup.timer'],
    requires=[
        'file: vault_full_backup_service',
        'cmd: vault_full_backup_service_daemon_reload',
        'file: vault_full_backup_timer',
        'cmd: vault_full_backup_timer_daemon_reload',
    ],
) }}
