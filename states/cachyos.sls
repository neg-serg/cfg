{# CachyOS kernel packages, boot configuration, and kernel cmdline management #}
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

cachyos_kernels:
  cmd.run:
    - name: sudo -u {{ host.user }} paru -S --noconfirm --needed {{ cachyos.kernel_packages | join(' ') }}
    - unless: grep -qxF 'linux-cachyos' {{ host.pkg_list }}
    - require:
      - cmd: pacman_db_warmup
      - file: cachyos_kernel_cmdline

cachyos_settings:
  cmd.run:
    - name: sudo -u {{ host.user }} paru -S --noconfirm --needed {{ cachyos.settings_package }}
    - unless: grep -qxF '{{ cachyos.settings_package }}' {{ host.pkg_list }}
    - require:
      - cmd: pacman_db_warmup
      - cmd: cachyos_kernels

cachyos_scx:
  cmd.run:
    - name: sudo -u {{ host.user }} paru -S --noconfirm --needed {{ cachyos.scx_packages | join(' ') }}
    - unless: grep -qxF '{{ cachyos.scx_packages[0] }}' {{ host.pkg_list }}
    - require:
      - cmd: pacman_db_warmup
      - cmd: cachyos_settings

{% for variant in cachyos.kernel_variants %}
{{ variant | replace('-', '_') }}_preset:
  file.managed:
    - name: /etc/mkinitcpio.d/{{ variant }}.preset
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
      - cmd: cachyos_settings
{% endfor %}

cachyos_mkinitcpio:
  cmd.run:
    - name: mkinitcpio -P
    - onlyif: command -v mkinitcpio >/dev/null 2>&1
    - onchanges:
      - file: cachyos_kernel_cmdline
      - cmd: cachyos_kernels
      - cmd: cachyos_boot_splash
{%- for variant in cachyos.kernel_variants %}
      - file: {{ variant | replace('-', '_') }}_preset
{%- endfor %}

cachyos_default_boot:
  cmd.run:
    - name: bootctl set-default {{ cachyos.boot_entry }}
    - onlyif: test -f /efi/EFI/Linux/{{ cachyos.boot_entry }}
    - unless: bootctl status 2>/dev/null | grep -qi 'default.*{{ cachyos.boot_entry | replace('.', '\.') }}'
    - require:
      - cmd: cachyos_mkinitcpio
