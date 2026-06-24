{# Limine bootloader: EFI binary deployment, config generation, and NixOS generation discovery. #}
{#- @state
   id: limine
   purpose: "Limine bootloader: EFI binary deployment, config generation, and NixOS generation discovery."
   data_files: [data/limine.yaml]
   configs: [configs/limine.cfg.j2]
#}
{% from '_imports.jinja' import host %}
{% import_yaml 'data/limine.yaml' as limine_yml %}

limine_package:
  pkg.installed:
    - name: {{ limine_yml.package }}

limine_efi_dir:
  file.directory:
    - name: {{ limine_yml.target_dir }}
    - mode: '0700'

limine_efi_binary:
  file.managed:
    - name: {{ limine_yml.target_efi }}
    - source: {{ limine_yml.source_efi }}
    - skip_verify: true
    - mode: '0600'
    - require:
      - pkg: limine_package
      - file: limine_efi_dir

limine_efi_entry:
  cmd.run:
    - name: |
        entry=$(efibootmgr 2>/dev/null | grep ' {{ limine_yml.efi_label }}$' | awk '{print $1}' | tr -d 'Boot*')
        if [ -z "$entry" ]; then
          efibootmgr --create --disk {{ limine_yml.esp_device }} --part {{ limine_yml.esp_part }} \
            --label "{{ limine_yml.efi_label }}" --loader \\EFI\\Limine\\liminex64.efi
          echo "EFI entry created"
        else
          echo "EFI entry exists: Boot$entry"
        fi
        current_first=$(efibootmgr 2>/dev/null | awk -F, '/^BootOrder:/ {print $2}')
        if [ -n "$entry" ] && [ "$current_first" != "$entry" ]; then
          full_order=$(efibootmgr 2>/dev/null | awk '/^BootOrder:/ {$1=""; print}' | sed 's/^ *//')
          efibootmgr --bootorder "$entry,$full_order" 2>/dev/null || true
          echo "BootOrder updated: Limine first"
        fi
    - require:
      - file: limine_efi_binary

limine_config:
  file.managed:
    - name: {{ limine_yml.config_path }}
    - source: salt://configs/limine.cfg.j2
    - template: jinja
    - mode: '0600'
    - context:
        limine_yml: {{ limine_yml | tojson }}
    - require:
      - file: limine_efi_binary

# NixOS generation entries appended by scripts/limine-generations.sh on config changes.
limine_nixos_generations:
  cmd.script:
    - source: salt://scripts/limine-generations.sh
    - shell: /bin/bash
    - runas: root
    - onchanges:
      - file: limine_config
