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
  - kernel_params_limine
  - mkinitcpio
  - sysctl
  - hardware
  - systemd_resources
