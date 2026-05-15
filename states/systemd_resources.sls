{# Systemd resource management: sysusers, tmpfiles, and service account provisioning #}
{#- @state
   id: systemd_resources
   purpose: "Systemd resource management: sysusers, tmpfiles, and service account provisioning."
   data_files: [data/managed_resources.yaml]
#}
# =============================================================================
# SystemD managed resources — identity guards and path protections
# =============================================================================
{% import_yaml 'data/managed_resources.yaml' as managed %}

{% set identities = managed.get('managed_service_identities', {}) %}
{% set paths = managed.get('managed_service_paths', {}) %}

# =============================================================================
# Subdomain: managed service identities (sysusers.d)
# =============================================================================

managed_service_accounts_dir:
  file.directory:
    - name: /etc/sysusers.d
    - user: root
    - group: root
    - mode: '0755'

{% set _sysusers_lines = ["# Managed by Salt. Do not edit manually."] %}
{% for _name, _entry in identities|dictsort %}
{% do _sysusers_lines.append(salt['service.managed_sysusers_line'](_entry)) %}
{% endfor %}

{{ salt['service.config_and_reload']('managed_service_accounts_conf', '/etc/sysusers.d/salt-managed-service-accounts.conf',
    'systemd-sysusers /etc/sysusers.d/salt-managed-service-accounts.conf',
    contents=_sysusers_lines|join('\n'),
    require=['file: managed_service_accounts_dir'],
    onlyif='command -v systemd-sysusers >/dev/null 2>&1') }}

managed_service_accounts_ensure:
  cmd.run:
    - name: systemd-sysusers /etc/sysusers.d/salt-managed-service-accounts.conf
{% if identities %}
    - unless: |
{%- for _name, _entry in identities|dictsort %}
        {{ salt['service.managed_identity_guard'](_entry) }}{% if not loop.last %} &&{% endif %}
{%- endfor %}
{% else %}
    - unless: test 1 = 1
{% endif %}
    - require:
      - file: managed_service_accounts_conf

# =============================================================================
# Subdomain: managed service paths (tmpfiles.d)
# =============================================================================

managed_service_paths_dir:
  file.directory:
    - name: /etc/tmpfiles.d
    - user: root
    - group: root
    - mode: '0755'

{% set _tmpfiles_lines = ["# Managed by Salt. Do not edit manually."] %}
{% for _name, _entry in paths|dictsort %}
{% do _tmpfiles_lines.append(salt['service.managed_tmpfiles_line'](_entry)) %}
{% endfor %}

{{ salt['service.config_and_reload']('managed_service_paths_conf', '/etc/tmpfiles.d/salt-managed-service-paths.conf',
    'systemd-tmpfiles --create /etc/tmpfiles.d/salt-managed-service-paths.conf',
    contents=_tmpfiles_lines|join('\n'),
    require=['file: managed_service_paths_dir'],
    onlyif='command -v systemd-tmpfiles >/dev/null 2>&1') }}

managed_service_paths_ensure:
  cmd.run:
    - name: |
        set -eo pipefail
        _ok=1
{% if paths %}
{% for _name, _entry in paths|dictsort %}
        if ! {{ salt['service.managed_path_guard'](_entry) }}; then
          _ok=0
        fi
{% endfor %}
        if [ "$_ok" -eq 1 ]; then
          echo "changed=no comment='managed service paths already present'"
        else
          systemd-tmpfiles --create /etc/tmpfiles.d/salt-managed-service-paths.conf
          echo "changed=yes comment='managed service paths reconciled'"
        fi
{% else %}
        echo "changed=no comment='no managed service paths declared'"
{% endif %}
    - onlyif: command -v systemd-tmpfiles >/dev/null 2>&1
    - shell: /bin/bash
    - stateful: True
{% if paths %}
    - require:
      - file: managed_service_paths_conf
{% endif %}
