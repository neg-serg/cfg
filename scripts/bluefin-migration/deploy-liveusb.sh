#!/bin/bash
# Deploy from Fedora 44 Live USB
# Run after booting Fedora 44 Workstation Live ISO
set -euo pipefail

# The image tar should be accessible (on USB or another partition)
IMAGE_TAR=/run/media/liveuser/zero/bluefin-custom.tar
ROOT_PART=/dev/nvme0n1p2

echo "=== Load image ==="
podman load -i "$IMAGE_TAR"

echo "=== Install to disk ==="
sudo bootc install to-disk --skip-fetch-check "$ROOT_PART"
# Note: this wipes the partition and sets up bootloader

echo "=== Add EFI entry ==="
sudo efibootmgr --create --label "Fedora Silverblue" \
  --loader '\EFI\fedora\shimx64.efi' --disk /dev/nvme0n1

echo "Done. Reboot."
