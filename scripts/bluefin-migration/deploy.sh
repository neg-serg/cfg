#!/bin/bash
# Deploy bluefin-custom to /dev/nvme0n1p2 using bootc install to-filesystem
# Uses existing EFI at nvme0n1p5. CachyOS host, non-destructive to host.
set -euo pipefail
ROOT_PART=/dev/nvme0n1p2
EFI_PART=/dev/nvme0n1p5
MNT=/mnt/bluefin

echo "=== Format $ROOT_PART ==="
mkfs.xfs -f -L bluefin "$ROOT_PART"

echo "=== Mount ==="
mkdir -p "$MNT"
mount "$ROOT_PART" "$MNT"
mkdir -p "$MNT/boot"
mount "$EFI_PART" "$MNT/boot"

echo "=== Get EFI UUID for kernel cmdline ==="
EFI_UUID=$(blkid -s UUID -o value "$EFI_PART")
echo "EFI UUID: $EFI_UUID"

echo "=== Install via bootc ==="
podman run --rm --privileged \
  -v "$MNT:/target" \
  -v /dev:/dev \
  --pid=host \
  bluefin-custom:latest \
  bootc install to-filesystem \
    --skip-fetch-check \
    --replace=wipe \
    --boot-mount-spec="UUID=$EFI_UUID" \
    --karg=root=LABEL=bluefin \
    --karg=rw \
    --bootloader=systemd \
    /target

echo "=== Add EFI boot entry ==="
efibootmgr --create --label "Bluefin (Silverblue)" \
  --loader '\EFI\systemd\systemd-bootx64.efi' \
  --disk "$(echo $ROOT_PART | sed 's/p[0-9]*$//')" \
  --part "$(echo $ROOT_PART | grep -oP '\d+$')" \
  2>/dev/null || echo "⚠️ Could not create EFI entry — use BIOS boot menu"

echo "=== Cleanup ==="
umount "$MNT/boot" 2>/dev/null || true
umount "$MNT" 2>/dev/null || true

echo ""
echo "✅ Done. Reboot and select 'Bluefin (Silverblue)' from BIOS."
echo "   First boot will walk through GNOME initial setup."
echo "   Then login: user created during setup."
echo "   Dotfiles auto-apply on first login."
echo "   Gopass auto-initializes from machine SSH host key."
