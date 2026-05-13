{# User-level desktop configuration: dotfiles, services, and session autostart #}
# =============================================================================
# Desktop user session — dconf, SSH keys, user services
# =============================================================================
{% from '_imports.jinja' import host, home %}


{% import_yaml 'data/desktop.yaml' as desktop %}

# --- SSH directory setup ---
{{ salt['service.ensure_dir']('ssh_dir', home ~ '/.ssh', mode='0700') }}

# --- dconf: GTK/icon/font theme for Wayland apps ---
{{ salt['desktop.dconf_settings']('dconf_themes', desktop.dconf_settings) }}

# --- Salt daemon systemd unit ---
salt_daemon_venv_ready:
  file.exists:
    - name: {{ host.project_dir }}/.venv/bin/python3

{{ salt['service.service_with_unit']('salt-daemon', 'salt://units/salt-daemon.service.j2', template='jinja', context={'project_dir': host.project_dir, 'runtime_dir': host.runtime_dir}, running=True, requires=['file: salt_daemon_venv_ready']) }}
