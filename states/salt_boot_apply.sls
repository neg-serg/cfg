{#- @state
   id: salt_boot_apply
   purpose: "Apply critical Salt states at boot via systemd oneshot service."
   feature_gate: []
   secrets: []
   services: [salt-boot-apply.service]
   config_references: []
#}
# =============================================================================
# Salt boot-time state application: group/core applied on boot.
# =============================================================================

{% from '_imports.jinja' import host %}

# Ensure the script is executable (it lives in the project repo)
salt_boot_apply_script:
  file.managed:
    - name: {{ host.project_dir }}/scripts/salt-boot-apply.sh
    - source: salt://scripts/salt-boot-apply.sh
    - mode: '0755'
    - user: root
    - group: root

# Deploy + enable the oneshot systemd unit
{{ salt['service.service_with_unit'](
    'salt-boot-apply',
    'salt://units/salt-boot-apply.service.j2',
    template='jinja',
    context={'project_dir': host.project_dir},
    running=False,
    enabled=True,
    requires=['file: salt_boot_apply_script'],
) }}
