#!/usr/bin/env bash
# Direct QEMU boot with virgl GPU + SSH forwarding.
# Usage: scripts/boot-vm.sh [RAM_MB] [CPUS] [SSH_PORT] [--headless]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
RAM="${1:-24576}"
CPUS="${2:-8}"
SSH_PORT="${3:-2222}"
DISK="${DISK_IMAGE:-${PROJECT_DIR}/nixos.qcow2}"
HEADLESS=0
[[ "${4:-}" == "--headless" ]] && HEADLESS=1

TOPL=$(nix build "path:${PROJECT_DIR}#nixosConfigurations.nixos.config.system.build.toplevel" \
  --print-out-paths --no-link --no-warn-dirty 2>/dev/null | tail -1)
[[ -d "$TOPL" ]] || { echo "ERROR: toplevel build failed"; exit 1; }

INITRD="$TOPL/initrd"
REGINFO=$(nix-store -q --references "$TOPL" | grep closure-info | head -1)
PARAMS=$(cat "$TOPL/kernel-params" 2>/dev/null)

echo "System: $(basename $TOPL)"
echo "RAM: ${RAM}MB  CPUs: $CPUS  Disk: $DISK  SSH: $SSH_PORT"
[[ $HEADLESS -eq 1 ]] && echo "Mode: headless (no GUI)" || echo "Mode: GPU (virgl)"

[[ -f "$DISK" ]] || { qemu-img create -f qcow2 "$DISK" 50G; }

# Build QEMU args based on mode
QEMU_ARGS=(
  -machine "accel=kvm:tcg,mem-merge=on" -cpu max -name nixos
  -m "$RAM" -smp "$CPUS"
  -device virtio-rng-pci
  -net nic,netdev=user.0,model=virtio
  -netdev "user,id=user.0,hostfwd=tcp::$SSH_PORT-:22"
  -drive "cache=writeback,file=$DISK,if=none,id=drive1,werror=report"
  -device virtio-blk-pci,bootindex=1,drive=drive1,serial=root
  -virtfs "local,path=/nix/store,security_model=none,mount_tag=nix-store"
  -device virtio-keyboard -usb -device usb-tablet
  -kernel "$TOPL/kernel" -initrd "$INITRD"
)

if [[ $HEADLESS -eq 1 ]]; then
  QEMU_ARGS+=(
    -append "init=$TOPL/init regInfo=$REGINFO $PARAMS console=ttyS0"
    -nographic
  )
else
  # virgl GPU: virtio-gpu with OpenGL acceleration
  QEMU_ARGS+=(
    -device virtio-vga-gl
    -display gtk,gl=on,grab-on-hover=on
    -append "init=$TOPL/init regInfo=$REGINFO $PARAMS console=tty0"
  )
fi

echo "Booting..."
"${QEMU_ARGS[@]}" > /tmp/nixos-vm-boot.log 2>&1 &
QEMU_PID=$!
echo "$QEMU_PID" > /tmp/nixos-vm-pid
echo "QEMU PID: $QEMU_PID"

for i in $(seq 1 120); do
  if ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
      -o ConnectTimeout=3 -p "$SSH_PORT" root@localhost 'echo ok' 2>/dev/null; then
    echo "SSH ready (${i}s)"
    echo "Connect: ssh -p $SSH_PORT root@localhost"
    [[ $HEADLESS -ne 1 ]] && echo "GUI:   QEMU window should be open"
    echo "Stop:    kill $QEMU_PID"
    exit 0
  fi
  sleep 1
done

echo "TIMEOUT — check /tmp/nixos-vm-boot.log"
kill $QEMU_PID 2>/dev/null
exit 1
