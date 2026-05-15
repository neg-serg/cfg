{# Core group: users, shell, mounts, kernel modules, sysctl, systemd resources #}
{#- @state
   id: group.core
   purpose: "Core group: users, shell, mounts, kernel modules, sysctl, systemd resources."
    includes: [bind_mounts, cachyos, fstab_column, hardware, kernel_modules, mkinitcpio, mounts, pacman_db_warmup, salt_boot_apply, sysctl, systemd_resources, users, windows_mount, zsh]
#}
# Group: system core — users, shell, mounts, kernel, hardware
# Usage: just apply group/core

include:
  - pacman_db_warmup
  - salt_boot_apply
  - users
  - zsh
  - mounts
  - bind_mounts
  - windows_mount
  - fstab_column
  - kernel_modules
  - mkinitcpio
  - sysctl
  - hardware
  - cachyos
  - systemd_resources
