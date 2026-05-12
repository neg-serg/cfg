{# Hardware-specific configuration: udev rules, fan control, WiFi drivers #}
{% from '_imports.jinja' import host %}
{% from '_macros_service.jinja' import udev_rule, service_with_unit %}
{% import_yaml 'data/hardware.yaml' as hw %}

{{ udev_rule('custom_udev_rules', hw.udev_rules_path, source='salt://configs/udev-custom.rules') }}

{% if host.features.fancontrol %}

fancontrol_setup_script:
  file.managed:
    - name: {{ hw.fancontrol_setup }}
    - source: salt://scripts/fancontrol-setup.sh
    - mode: '0755'

fancontrol_reapply_script:
  file.managed:
    - name: {{ hw.fancontrol_reapply }}
    - makedirs: True
    - mode: '0755'
    - source: salt://scripts/fancontrol-reapply.sh.j2
    - template: jinja
    - context:
        cpu_vendor: {{ host.cpu_vendor }}

{{ service_with_unit('fancontrol-setup', 'salt://units/fancontrol-setup.service.j2', template='jinja', context={'gpu_enable': host.cpu_vendor == 'amd'}, enabled=None) }}

{{ service_with_unit('fancontrol', 'salt://units/fancontrol.service', requires=['cmd: fancontrol-setup_daemon_reload', 'file: fancontrol_setup_script']) }}

nct6775_module:
  cmd.run:
    - name: |
        set -euo pipefail
        if lsmod | awk '{print $1}' | grep -Fxq {{ hw.nct6775_module }}; then
          echo "changed=no comment='{{ hw.nct6775_module }} already loaded'"
        elif modinfo {{ hw.nct6775_module }} >/dev/null 2>&1; then
          modprobe {{ hw.nct6775_module }}
          echo "changed=yes comment='loaded {{ hw.nct6775_module }}'"
        else
          echo "changed=no comment='{{ hw.nct6775_module }} unavailable on this kernel; skipping'"
        fi
    - shell: /bin/bash
    - onlyif: command -v lsmod >/dev/null 2>&1 && command -v modinfo >/dev/null 2>&1 && command -v modprobe >/dev/null 2>&1
    - stateful: True

{% endif %}

{% if host.cpu_vendor == 'amd' %}
{{ service_with_unit('gpu-power-profile', 'salt://units/gpu-power-profile.service', enabled=True) }}
{% endif %}

{% if not host.features.network.wifi %}

rfkill_service_masked:
  service.masked:
    - name: systemd-rfkill.service

rfkill_socket_masked:
  service.masked:
    - name: systemd-rfkill.socket

{% endif %}

{% if 'snd_hdspe' in host.extra_modules %}
rme_hdspe_dkms_add:
  cmd.run:
    - name: dkms add {{ hw.hdspe.source }} 2>/dev/null || true
    - unless: test -d /var/lib/dkms/{{ hw.hdspe.dkms_name }}
    - onlyif: test -d {{ hw.hdspe.source }}

rme_hdspe_dkms_build:
  cmd.run:
    - name: dkms build {{ hw.hdspe.dkms_name }}/{{ hw.hdspe.dkms_version }}
    - unless: test -f /var/lib/dkms/{{ hw.hdspe.dkms_name }}/{{ hw.hdspe.dkms_version }}/$(uname -r)/*/module/snd-hdspe.ko* 2>/dev/null
    - require:
      - cmd: rme_hdspe_dkms_add

rme_hdspe_dkms_install:
  cmd.run:
    - name: dkms install {{ hw.hdspe.dkms_name }}/{{ hw.hdspe.dkms_version }}
    - unless: test -f /usr/lib/modules/$(uname -r)/updates/dkms/snd-hdspe.ko* 2>/dev/null
    - require:
      - cmd: rme_hdspe_dkms_build
{% endif %}
