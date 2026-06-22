#!/bin/bash
# deploy.sh — deploy bluefin-custom to disk
# Step 1: Deploy ostree commit (RPM layer)
# Step 2: Extract host-built tarball on top
# Step 3: Setup bootloader
set -euo pipefail
ROOT=/dev/nvme0n1p2; EFI=/dev/nvme0n1p5; MNT=/mnt/bluefin
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── Format ─────────────────────────────────────────────────────
sudo umount $MNT/boot 2>/dev/null || true
sudo umount $MNT 2>/dev/null || true
sudo mkfs.xfs -f -L bluefin $ROOT 2>&1 | tail -1

# ── Extract ostree repo ────────────────────────────────────────
sudo mkdir -p $MNT && sudo mount $ROOT $MNT
sudo chown -R 1000:1000 $MNT

echo "Extracting ostree..."
podman run --rm --entrypoint="" bluefin-custom:latest \
  tar cf - -C /ostree/repo . 2>/dev/null | tar xf - -C $MNT/ostree/repo/ 2>/dev/null

# ── Deploy ostree commit ──────────────────────────────────────
COMMIT=$(podman run --rm bluefin-custom:latest sh -c \
  'for f in /ostree/repo/objects/*/*.commit; do echo "$(basename $(dirname $f))$(basename $f .commit)"; done' | head -1)

sudo mkdir -p $MNT/boot && sudo mount -t tmpfs tmpfs $MNT/boot
sudo chown 1000:1000 $MNT/boot

echo "Deploying commit $COMMIT..."
podman run --rm --privileged \
  -v $MNT:/target -v $MNT/boot:/target/boot --pid=host \
  bluefin-custom:latest sh -c "
    mkdir -p /target/ostree/deploy/bluefin/var
    touch /target/ostree/deploy/bluefin/.ostree-stateroot
    ostree admin deploy --sysroot=/target --os=bluefin --karg=root=LABEL=bluefin --karg=rw --karg=selinux=0 "'"$COMMIT"'"' 2>&1 || true
  " 2>&1 | tail -3

# ── Extract host-built files on top ───────────────────────────
DEPLOY_DIR=$MNT/ostree/deploy/bluefin/deploy/${COMMIT}.0
sudo mkdir -p "$DEPLOY_DIR"
echo "Extracting host-built..."
podman run --rm --entrypoint="" bluefin-custom:latest \
  tar cf - -C /usr . 2>/dev/null | sudo tar xf - -C "$DEPLOY_DIR/usr/" 2>/dev/null
podman run --rm --entrypoint="" bluefin-custom:latest \
  tar cf - -C /opt . 2>/dev/null | sudo tar xf - -C "$DEPLOY_DIR/opt/" 2>/dev/null
podman run --rm --entrypoint="" bluefin-custom:latest \
  tar cf - -C /etc/skel . 2>/dev/null | sudo tar xf - -C "$DEPLOY_DIR/etc/skel/" 2>/dev/null

echo "✅ System deployed at $DEPLOY_DIR"

# ── Bootloader ─────────────────────────────────────────────────
sudo umount $MNT/boot
sudo mount $EFI $MNT/boot
sudo mkdir -p $MNT/boot/loader/entries

# Find kernel
KERNEL=$(ls $DEPLOY_DIR/usr/lib/modules/ 2>/dev/null | head -1)
sudo cat > $MNT/boot/loader/entries/bluefin.conf << CONF
title Bluefin Custom
linux /ostree/bluefin-$COMMIT/vmlinuz-$KERNEL
initrd /ostree/bluefin-$COMMIT/initramfs-$KERNEL.img
options root=LABEL=bluefin rw selinux=0
CONF

echo "✅ Boot entry created"
sudo umount $MNT/boot 2>/dev/null || true
sudo umount $MNT 2>/dev/null || true

echo ""
echo "✅ Done. Reboot and select 'Bluefin Custom' from BIOS."
echo "   Kernel: $KERNEL"
