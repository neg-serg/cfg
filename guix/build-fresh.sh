#!/bin/bash
# Build fresh Guix image with SSH by booting old VM and running guix system image
set -e

sudo pkill -9 qemu 2>/dev/null; sleep 2
cp /usr/share/edk2/x64/OVMF_VARS.4m.fd /tmp/guix-vm-vars.fd
qemu-img create -f qcow2 /tmp/guix-data.qcow2 2G 2>/dev/null

# Create a FIFO for QEMU input
rm -f /tmp/qemu-in
mkfifo /tmp/qemu-in

# Start QEMU with stdin from FIFO
sudo qemu-system-x86_64 -enable-kvm -cpu host -smp 12 -m 8G \
  -drive file=/var/lib/libvirt/images/guix-system-vm-1.5.0.qcow2,if=virtio \
  -drive file=/tmp/guix-data.qcow2,if=virtio \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/x64/OVMF_CODE.4m.fd \
  -drive if=pflash,format=raw,file=/tmp/guix-vm-vars.fd \
  -nographic -net nic,model=virtio -net user \
  -no-reboot < /tmp/qemu-in &
QPID=$!
echo "QEMU PID: $QPID"

# Feed commands through FIFO with timing
(
  # Wait for GRUB, send Enter
  sleep 20
  echo "" > /tmp/qemu-in
  
  # Wait for boot + login prompt
  sleep 90
  
  # Login as guest
  echo "guest" > /tmp/qemu-in
  sleep 3
  echo "guix" > /tmp/qemu-in
  sleep 3
  
  # Become root
  echo "sudo -i" > /tmp/qemu-in
  sleep 3
  
  # Format data disk
  echo "mkfs.ext4 -F /dev/vdb && mount /dev/vdb /mnt" > /tmp/qemu-in
  sleep 5
  
  # Run guix system image
  echo "guix system image -t qcow2 /etc/config.scm -L /home/guest/cfg-channel" > /tmp/qemu-in
  
  # Wait for build (keeps QEMU alive)
  sleep 14400
) &

echo "Build started. PID: $QPID"
wait $QPID
echo "=== DONE ==="
