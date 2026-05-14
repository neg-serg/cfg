{# Kernel module blacklisting and loading for hardware and virtualization #}
{#- @state
   id: kernel_modules
   purpose: "Kernel module blacklisting and loading for hardware and virtualization."
   data_files: [data/kernel_params.yaml]
   configs: [configs/modprobe-blacklist.conf.j2]
#}
{% from '_imports.jinja' import host %}
{% import_yaml 'data/kernel_params.yaml' as kernel_params %}

kernel_modules_load:
  file.managed:
    - name: /etc/modules-load.d/custom.conf
    - contents: |
        # KVM virtualization ({{ host.cpu_vendor }})
        {{ host.kvm_module }}
        # BBR TCP congestion control
        tcp_bbr
        # NT synchronization primitives (Wine/Proton)
        ntsync
        # NTFS3 in-kernel driver (auto-loaded on mount, explicit for clarity)
        ntfs3
{% for mod in host.extra_modules %}
        # Host-specific: {{ mod }}
        {{ mod }}
{% endfor %}

kernel_modules_blacklist:
  file.managed:
    - name: /etc/modprobe.d/blacklist-custom.conf
    - source: salt://configs/modprobe-blacklist.conf.j2
    - template: jinja
    - context:
        cpu_vendor: {{ host.cpu_vendor }}

{% set modules_to_load = [host.kvm_module, 'tcp_bbr', 'ntsync', 'ntfs3'] + host.extra_modules %}
{% for mod in modules_to_load %}
load_{{ mod | replace('-', '_') }}:
  cmd.run:
    - name: modprobe {{ mod }} 2>/dev/null || true
    - unless: lsmod | grep -q '^{{ mod }}\b'
    - require:
      - file: kernel_modules_load
{% endfor %}
