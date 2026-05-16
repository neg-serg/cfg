{# CachyOS kernel packages, boot configuration, and kernel cmdline management #}
{#- @state
   id: cachyos
   purpose: "CachyOS kernel packages, boot configuration, and kernel cmdline management."
   includes: [pacman_db_warmup]
   data_files: [data/cachyos.yaml, data/hosts.yaml, data/kernel_params.yaml]
   configs: [configs/kernel-cmdline.j2, configs/mkinitcpio-cachyos-preset.j2]
#}
{% from '_imports.jinja' import host %}
{% import_yaml 'data/cachyos.yaml' as cachyos %}

include:
  - pacman_db_warmup

cachyos_boot_splash:
  cmd.run:
    - name: python3 {{ host.project_dir }}/scripts/generate-boot-splash.py --display {{ host.display }} --output {{ cachyos.boot_splash.output }}
    - unless: test -f {{ cachyos.boot_splash.output }}

cachyos_kernel_cmdline:
  file.managed:
    - name: {{ cachyos.kernel_cmdline_path }}
    - source: salt://configs/kernel-cmdline.j2
    - template: jinja
    - mode: '0644'
    - require:
      - cmd: cachyos_boot_splash

{{ salt['pkg.paru_install']('cachyos_kernels', cachyos.kernel_packages | join(' '), requires=['file: cachyos_kernel_cmdline']) }}

{{ salt['pkg.paru_install']('cachyos_settings', cachyos.settings_package, requires=['cmd: install_cachyos_kernels']) }}

{{ salt['pkg.paru_install']('cachyos_scx', cachyos.scx_packages | join(' '), requires=['cmd: install_cachyos_settings']) }}

{% for variant in cachyos.kernel_variants %}
{{ variant | replace('-', '_') }}_preset:
  file.managed:
    - name: {{ host.mkinitcpio_dir }}{{ variant }}.preset
    - source: salt://configs/mkinitcpio-cachyos-preset.j2
    - template: jinja
    - context:
        variant: {{ variant }}
    - mode: '0644'
{% endfor %}

{% for svc in cachyos.services %}
{{ svc | replace('-', '_') | replace('.', '_') }}:
  service.running:
    - name: {{ svc }}
    - enable: true
    - onlyif: systemctl list-unit-files {{ svc }} &>/dev/null
    - require:
      - cmd: install_cachyos_settings
{% endfor %}

cachyos_mkinitcpio:
  cmd.run:
    - name: mkinitcpio -P
    - onlyif: command -v mkinitcpio >/dev/null 2>&1
    - parallel: True
    - onchanges:
      - file: cachyos_kernel_cmdline
      - cmd: install_cachyos_kernels
      - cmd: cachyos_boot_splash
{%- for variant in cachyos.kernel_variants %}
      - file: {{ variant | replace('-', '_') }}_preset
{%- endfor %}

cachyos_default_boot:
  cmd.run:
    - name: bootctl set-default {{ cachyos.boot_entry }}
    - onlyif: test -f {{ cachyos.boot_efi_dir }}/{{ cachyos.boot_entry }}
    - unless: bootctl status 2>/dev/null | grep -qi 'default.*{{ cachyos.boot_entry | replace('.', '\.') }}'
    - require:
      - cmd: cachyos_mkinitcpio
