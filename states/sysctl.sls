{# Kernel sysctl parameters: custom tuning for networking, filesystems, and security #}
# Sysctl settings migrated from NixOS
# (modules/system/kernel/sysctl.nix, sysctl-mem-extras.nix, sysctl-writeback.nix,
#  hosts/telfir/hardware.nix)
#
# Dropped into /etc/sysctl.d/ and applied via sysctl --system.

sysctl_config:
  file.managed:
    - name: /etc/sysctl.d/99-custom.conf
    - source: salt://configs/sysctl-custom.conf
    - mode: '0644'

sysctl_apply:
  cmd.run:
    - name: sysctl --system
    - onlyif: command -v sysctl >/dev/null 2>&1
    - onchanges:
      - file: sysctl_config
