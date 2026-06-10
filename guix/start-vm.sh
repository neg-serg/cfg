#!/bin/bash
set -e

IMAGE="/var/lib/libvirt/images/guix-system-vm-1.5.0.qcow2"
PIDFILE="/tmp/guix-vm.pid"
SERIAL_LOG="/tmp/guix-vm-serial.log"

case "${1:-start}" in
  start)
    if [ -f "$PIDFILE" ] && kill -0 $(cat "$PIDFILE") 2>/dev/null; then
      echo "VM already running (pid $(cat $PIDFILE))"
      exit 0
    fi
    echo "Starting Guix VM..."
    > "$SERIAL_LOG"
    exec setsid qemu-system-x86_64 \
      -machine q35,accel=kvm \
      -cpu host \
      -smp 4 \
      -m 4096 \
      -drive file="$IMAGE",if=virtio,format=qcow2 \
      -nic user,hostfwd=tcp::10022-:22,hostfwd=tcp::10080-:80 \
      -vga virtio \
      -display none \
      -serial file:"$SERIAL_LOG" \
      -device virtio-rng-pci \
      -pidfile "$PIDFILE" \
      -bios /usr/share/edk2/x64/OVMF_CODE.4m.fd \
      </dev/null &>/dev/null &
    disown
    echo "VM starting in background (pid $(cat $PIDFILE 2>/dev/null || echo '?'))"
    ;;
  stop)
    if [ -f "$PIDFILE" ]; then
      pid=$(cat "$PIDFILE")
      echo "Stopping VM (pid $pid)..."
      kill "$pid" 2>/dev/null || true
      rm -f "$PIDFILE"
      echo "Stopped."
    else
      echo "No PID file found."
    fi
    ;;
  status)
    if [ -f "$PIDFILE" ] && kill -0 $(cat "$PIDFILE") 2>/dev/null; then
      echo "VM is running (pid $(cat $PIDFILE))"
      echo "SSH: ssh -p 10022 root@localhost"
    else
      echo "VM is not running"
    fi
    ;;
  console)
    if [ -f "$SERIAL_LOG" ]; then
      tail -f "$SERIAL_LOG"
    else
      echo "No serial log found"
    fi
    ;;
  *)
    echo "Usage: $0 {start|stop|status|console}"
    exit 1
    ;;
esac
