#!/bin/bash
# Deploy bluefin-custom to /dev/nvme0n1p2 (old Guix partition)
# Uses existing EFI at nvme0n1p5. Must run as root.
set -euo pipefail
DISK=/dev/nvme0n1p2
EFI=/dev/nvme0n1p5
ROOT=/mnt/bluefin

echo "=== Format $DISK ==="
mkfs.xfs -f -L bluefin "$DISK"

echo "=== Mount ==="
mkdir -p "$ROOT"
mount "$DISK" "$ROOT"

echo "=== Init ostree ==="
podman run --rm --privileged -v "$ROOT:/target" bluefin-custom:latest \
  ostree admin init-fs /target --sysroot /target

echo "=== Get commit ==="
REV=$(podman run --rm bluefin-custom:latest ostree refs --repo=/ostree/repo 2>/dev/null | head -1)
REV=${REV##*:}
[ -z "$REV" ] && REV=$(podman run --rm bluefin-custom:latest sh -c 'rpm-ostree status 2>/dev/null | grep Commit | head -1' | awk '{print $2}')
echo "Commit: $REV"

echo "=== Pull commit ==="
podman run --rm --privileged --pid=host -v "$ROOT:/target" bluefin-custom:latest sh -c "
  mkdir -p /target/sysroot/ostree/repo
  ostree --repo=/target/sysroot/ostree/repo pull-local /ostree/repo '$REV'
"

echo "=== Deploy ==="
podman run --rm --privileged -v "$ROOT:/target" bluefin-custom:latest sh -c "
  cd /target
  ostree admin deploy --sysroot=/target --os=bluefin --karg=root=LABEL=bluefin --karg=rw '$REV'
"

echo "=== EFI ==="
mkdir -p "$ROOT/boot" && mount "$EFI" "$ROOT/boot"
# Copy systemd-boot EFI stub
podman run --rm --privileged -v "$ROOT:/target" bluefin-custom:latest sh -c '
  mkdir -p /target/boot/EFI/BOOT /target/boot/EFI/Linux
  cp /usr/lib/systemd/boot/efi/systemd-bootx64.efi /target/boot/EFI/BOOT/BOOTX64.EFI 2>/dev/null || true
  cp /boot/efi/EFI/Linux/* /target/boot/EFI/Linux/ 2>/dev/null || true
'
umount "$ROOT/boot" 2>/dev/null || true

echo ""
echo "Done. Boot entry:"
echo "  efibootmgr --create --label Bluefin --loader '\\EFI\\BOOT\\BOOTX64.EFI' --disk /dev/nvme0n1"
echo ""
echo "  or add to existing systemd-boot via loader/entries/bluefin.conf"
umount "$ROOT" 2>/dev/null || true
