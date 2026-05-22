#!/usr/bin/env bash
# Direct QEMU boot with correct toplevel — bypasses run-nixos-vm caching.
# Usage: scripts/boot-vm.sh [RAM_MB] [CPUS] [SSH_PORT]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
RAM="${1:-16384}"
CPUS="${2:-8}"
SSH_PORT="${3:-2222}"
DISK="${DISK_IMAGE:-/tmp/nixos-vm.qcow2}"

TOPL=$(nix build "path:${PROJECT_DIR}#nixosConfigurations.nixos.config.system.build.toplevel" \
  --print-out-paths --no-link --no-warn-dirty 2>/dev/null | tail -1)
[[ -d "$TOPL" ]] || { echo "ERROR: toplevel build failed"; exit 1; }

INITRD="$TOPL/initrd"
REGINFO=$(nix-store -q --references "$TOPL" | grep closure-info | head -1)
PARAMS=$(cat "$TOPL/kernel-params" 2>/dev/null)

echo "System: $(basename $TOPL)"
echo "RAM: ${RAM}MB  CPUs: $CPUS  Disk: $DISK  SSH: $SSH_PORT"

[[ -f "$DISK" ]] || { qemu-img create -f qcow2 "$DISK" 50G; }

echo "Booting..."
qemu-system-x86_64 \
  -machine accel=kvm:tcg -cpu max -name nixos \
  -m "$RAM" -smp "$CPUS" \
  -device virtio-rng-pci \
  -net nic,netdev=user.0,model=virtio \
  -netdev "user,id=user.0,hostfwd=tcp::$SSH_PORT-:22" \
  -drive "cache=writeback,file=$DISK,if=none,id=drive1,werror=report" \
  -device virtio-blk-pci,bootindex=1,drive=drive1,serial=root \
  -virtfs local,path=/nix/store,security_model=none,mount_tag=nix-store \
  -device virtio-keyboard -usb -device usb-tablet \
  -kernel "$TOPL/kernel" -initrd "$INITRD" \
  -append "init=$TOPL/init regInfo=$REGINFO $PARAMS console=tty0" \
  -nographic > /tmp/nixos-vm-boot.log 2>&1 &
QEMU_PID=$!
echo "QEMU PID: $QEMU_PID"

for i in $(seq 1 120); do
  if ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
      -o ConnectTimeout=3 -p "$SSH_PORT" root@localhost 'echo ok' 2>/dev/null; then
    echo "SSH ready (${i}s)"
    echo "Connect: ssh -p $SSH_PORT root@localhost"
    echo "Stop:    kill $QEMU_PID"
    exit 0
  fi
  sleep 1
done

echo "TIMEOUT — check /tmp/nixos-vm-boot.log"
kill $QEMU_PID 2>/dev/null
exit 1
