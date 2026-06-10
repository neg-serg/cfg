#!/bin/bash
# Activate Guix channel inside VM and reconfigure system
# Usage: ./guix/activate-channel.sh

set -euo pipefail

VM_SSH="ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ~/.ssh/id_ed25519 -p 10023 guest@localhost"
CHANNEL_DIR="/home/neg/src/cfg/guix/channel"
VM_CHANNEL_DIR="/home/guest/cfg-channel"

echo "=== Copying custom channel to VM ==="
scp -r -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    -i ~/.ssh/id_ed25519 -P 10023 \
    "$CHANNEL_DIR" guest@localhost:/home/guest/

echo ""
echo "=== Copying system config to VM ==="
scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    -i ~/.ssh/id_ed25519 -P 10023 \
    /home/neg/src/cfg/guix/system-config.scm guest@localhost:/tmp/config.scm

echo ""
echo "=== Running guix system reconfigure ==="
$VM_SSH "sudo cp /tmp/config.scm /etc/config.scm && sudo guix system reconfigure /etc/config.scm -L $VM_CHANNEL_DIR"

echo ""
echo "=== Done! ==="
echo "To rebuild after channel changes:"
echo "  $VM_SSH 'cd $VM_CHANNEL_DIR && guix pull -L . && sudo guix system reconfigure /etc/config.scm -L $VM_CHANNEL_DIR'"
