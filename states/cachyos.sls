# CachyOS kernel packages, settings, and boot configuration.
# Manages kernel cmdline (embedded in UKI) and CachyOS-specific packages.
#
# Run: sudo salt-call --local -c .salt_runtime state.sls cachyos

{% from '_macros_pkg.jinja' import paru_install %}
{% from '_macros_common.jinja' import host %}

include:
  - pacman_db_warmup

# ── Kernel cmdline (written before kernel pkgs so UKI embeds it) ─────
cachyos_kernel_cmdline:
  file.managed:
    - name: /etc/kernel/cmdline
    - source: salt://configs/kernel-cmdline.j2
    - template: jinja
    - mode: '0644'

# ── Kernel packages ──────────────────────────────────────────────────
cachyos_kernels:
  cmd.run:
    - name: sudo -u {{ host.user }} paru -S --noconfirm --needed linux-cachyos linux-cachyos-headers linux-cachyos-eevdf linux-cachyos-eevdf-headers linux-cachyos-hardened linux-cachyos-hardened-headers linux-cachyos-lts linux-cachyos-lts-headers
    - unless: grep -qxF 'linux-cachyos' {{ host.pkg_list }}
    - require:
      - cmd: pacman_db_warmup
      - file: cachyos_kernel_cmdline

# ── CachyOS settings ─────────────────────────────────────────────────
cachyos_settings:
  cmd.run:
    - name: sudo -u {{ host.user }} paru -S --noconfirm --needed cachyos-settings
    - unless: grep -qxF 'cachyos-settings' {{ host.pkg_list }}
    - require:
      - cmd: pacman_db_warmup
      - cmd: cachyos_kernels

# ── sched-ext userspace (BPF schedulers + scx_loader) ────────────────
cachyos_scx:
  cmd.run:
    - name: sudo -u {{ host.user }} paru -S --noconfirm --needed scx-scheds scx-tools
    - unless: grep -qxF 'scx-scheds' {{ host.pkg_list }}
    - require:
      - cmd: pacman_db_warmup
      - cmd: cachyos_settings

# ── CachyOS mkinitcpio presets (enable UKI generation) ───────────────
{% set cachyos_variants = ['linux-cachyos', 'linux-cachyos-eevdf', 'linux-cachyos-hardened', 'linux-cachyos-lts'] %}
{% for variant in cachyos_variants %}
{{ variant | replace('-', '_') }}_preset:
  file.managed:
    - name: /etc/mkinitcpio.d/{{ variant }}.preset
    - source: salt://configs/mkinitcpio-cachyos-preset.j2
    - template: jinja
    - context:
        variant: {{ variant }}
    - mode: '0644'
{% endfor %}

# ── CachyOS services ─────────────────────────────────────────────────
cachyos_ananicy:
  service.running:
    - name: ananicy-cpp
    - enable: true
    - require:
      - cmd: cachyos_settings

cachyos_wireless_regdomain:
  service.running:
    - name: cachyos-iw-set-regdomain.path
    - enable: true
    - require:
      - cmd: cachyos_settings

# ── Rebuild all UKIs ─────────────────────────────────────────────────
cachyos_mkinitcpio:
  cmd.run:
    - name: mkinitcpio -P
    - onlyif: command -v mkinitcpio >/dev/null 2>&1
    - onchanges:
      - file: cachyos_kernel_cmdline
      - cmd: cachyos_kernels
{%- for variant in cachyos_variants %}
      - file: {{ variant | replace('-', '_') }}_preset
{%- endfor %}

# ── Default boot entry → linux-cachyos ───────────────────────────────
cachyos_default_boot:
  cmd.run:
    - name: bootctl set-default arch-linux-cachyos.efi
    - onlyif: test -f /boot/EFI/Linux/arch-linux-cachyos.efi
    - unless: bootctl status 2>/dev/null | grep -qi 'default.*arch-linux-cachyos.efi'
    - require:
      - cmd: cachyos_mkinitcpio
