{# Core group: users, shell, mounts, kernel modules, sysctl, systemd resources #}
# Group: system core — users, shell, mounts, kernel, hardware
# Usage: just apply group/core

include:
  - pacman_db_warmup
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
