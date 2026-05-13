{# Kernel sysctl parameters: custom tuning for networking, filesystems, and security
   Data-driven from states/data/sysctl.yaml via Jinja2 template. #}
{% from '_imports.jinja' import host %}

sysctl_config:
  file.managed:
    - name: {{ host.sysctl_dir }}99-custom.conf
    - source: salt://configs/sysctl-custom.conf.j2
    - template: jinja
    - mode: '0644'

sysctl_apply:
  cmd.run:
    - name: sysctl --system
    - onlyif: command -v sysctl >/dev/null 2>&1
    - onchanges:
      - file: sysctl_config
