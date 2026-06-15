#!/bin/bash
# Guix VM manager — start, stop, ssh into the Guix System VM
# SSH port: 2222 (guest), 10023 (host)
set -e

VM_NAME=guix
SSH_PORT=10023
GUEST_PORT=2222
IMAGE=/mnt/one/vms/guix.qcow2

stop_vm() {
  sudo virsh destroy "$VM_NAME" 2>/dev/null || true
  sudo virsh undefine "$VM_NAME" --nvram 2>/dev/null || true
  fuser -k "${SSH_PORT}/tcp" 2>/dev/null || true
}

start_vm() {
  cp /usr/share/edk2/x64/OVMF_VARS.4m.fd /home/neg/src/cfg/vms/guix-vm-vars.fd
  sudo virsh define /home/neg/src/cfg/vms/guix.xml 2>/dev/null || true
  sudo virsh start "$VM_NAME" 2>/dev/null || true
}

# Also update the XML image path if needed
fix_image_path() {
  python3 -c "
import xml.etree.ElementTree as ET
tree = ET.parse('/home/neg/src/cfg/vms/guix.xml')
for el in tree.iter():
    if el.get('file','').endswith('guix.qcow2'):
        el.set('file', '$IMAGE')
        tree.write('/home/neg/src/cfg/vms/guix.xml')
        print('image path fixed')
        break
" 2>/dev/null || true
}

add_port_forward() {
  sudo virsh qemu-monitor-command "$VM_NAME" \
    --hmp "hostfwd_add ::${SSH_PORT}-:${GUEST_PORT}" 2>/dev/null || true
  sleep 2
}

case "${1:-status}" in
  start)
    stop_vm
    start_vm
    echo "Waiting for VM to boot... (~60s)"
    sleep 60
    add_port_forward
    echo "VM ready — connect:"
    echo "  ssh -i ~/.ssh/id_ed25519 -p $SSH_PORT neg@localhost"
    ;;
  ssh)
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
      -i ~/.ssh/id_ed25519 -p "$SSH_PORT" neg@localhost "${@:2}"
    ;;
  console)
    sudo virsh console "$VM_NAME" --force
    ;;
  stop)
    stop_vm
    echo "VM stopped"
    ;;
  status)
    sudo virsh list --all | grep "$VM_NAME" || echo "not defined"
    ;;
  *)
    echo "Usage: $0 {start|ssh|console|stop|status}"
    ;;
esac
