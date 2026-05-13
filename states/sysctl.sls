{# Kernel sysctl parameters: custom tuning for networking, filesystems, and security
   Data-driven from states/data/sysctl.yaml via Jinja2 template. #}
{% from '_imports.jinja' import host %}

{{ salt['service.config_and_reload']('sysctl_config', host.sysctl_dir ~ '99-custom.conf', 'sysctl --system',
    source='salt://configs/sysctl-custom.conf.j2', template='jinja',
    onlyif='command -v sysctl >/dev/null 2>&1') }}
