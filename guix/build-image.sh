#!/bin/bash
# Build Guix VM image inside container
# Requires: podman, guix-modern image built from guix/Dockerfile
set -euo pipefail

CONFIG=/home/neg/src/cfg/guix/system-config.scm
CHANNEL=/home/neg/src/cfg/guix/channel
OUTPUT=/var/lib/libvirt/images/guix-system-vm-new.qcow2
STORE_VOL=guix-store
PULL_VOL=guix-pull

echo "=== Step 1: Create persistent volumes ==="
podman volume create $STORE_VOL 2>/dev/null || true
podman volume create $PULL_VOL 2>/dev/null || true

echo "=== Step 2: Run guix pull (update channels) ==="
# This downloads the latest package definitions
podman run --rm \
  -v $STORE_VOL:/gnu \
  -v $PULL_VOL:/root/.cache/guix \
  -v $CHANNEL:/channel:ro \
  guix-modern bash -c '
    export PATH=/root/.guix-profile/bin:$PATH
    guix-daemon --build-users-group=guixbuild --disable-chroot &
    sleep 3
    export GUIX_DAEMON_SOCKET=/var/guix/daemon-socket/socket
    echo "Running guix pull..."
    guix pull --substitute-urls="https://bordeaux.guix.gnu.org https://mirror.yandex.ru/mirrors/guix/" 2>&1
    echo "guix pull complete."
  ' 2>&1 | tail -20

echo ""
echo "=== Step 3: Build VM image ==="
# This builds the actual qcow2 image from our config
podman run --rm \
  -v $STORE_VOL:/gnu \
  -v $PULL_VOL:/root/.cache/guix \
  -v $CONFIG:/cfg/config.scm:ro \
  -v $CHANNEL:/channel:ro \
  -v /var/lib/libvirt/images:/output \
  guix-modern bash -c '
    export PATH=/root/.guix-profile/bin:$PATH
    guix-daemon --build-users-group=guixbuild --disable-chroot &
    sleep 3
    export GUIX_DAEMON_SOCKET=/var/guix/daemon-socket/socket
    echo "Running guix system image..."
    guix system image -t qcow2 /cfg/config.scm \
      -L /channel \
      --image-size=30G \
      --substitute-urls="https://bordeaux.guix.gnu.org https://mirror.yandex.ru/mirrors/guix/" \
      2>&1
    # Copy result to output
    cp /gnu/store/*-image.qcow2 /output/guix-system-vm-new.qcow2 2>/dev/null || true
  ' 2>&1

echo ""
echo "=== Done! Image at: $OUTPUT ==="
ls -la $OUTPUT 2>/dev/null || echo "Image not found — check build output above"
