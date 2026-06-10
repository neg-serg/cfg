#!/bin/bash
# Sync custom channel to VM and build all packages
# Usage: ./guix/sync-and-build.sh [step]
set -e

VM_SSH="ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -i ~/.ssh/id_ed25519 -p 10023 neg@localhost"
CHANNEL_DIR=/home/neg/src/cfg/guix/channel
VM_CHANNEL_DIR=/home/neg/cfg-channel

step_sync() {
  echo "=== Syncing channel to VM ==="
  ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    -i ~/.ssh/id_ed25519 -p 10023 neg@localhost \
    "mkdir -p $VM_CHANNEL_DIR/custom/packages $VM_CHANNEL_DIR/custom/services"
  
  scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    -i ~/.ssh/id_ed25519 -P 10023 \
    "$CHANNEL_DIR/.guix-channel" \
    neg@localhost:$VM_CHANNEL_DIR/
  
  scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    -i ~/.ssh/id_ed25519 -P 10023 \
    "$CHANNEL_DIR"/custom/packages/*.scm \
    neg@localhost:$VM_CHANNEL_DIR/custom/packages/
  
  scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    -i ~/.ssh/id_ed25519 -P 10023 \
    "$CHANNEL_DIR"/custom/services/*.scm \
    neg@localhost:$VM_CHANNEL_DIR/custom/services/
  
  # Copy system config
  scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    -i ~/.ssh/id_ed25519 -P 10023 \
    /home/neg/src/cfg/guix/system-config.scm \
    neg@localhost:/tmp/config.scm
  
  echo "=== Sync done ==="
}

step_build_vicinae() {
  echo "=== Building vicinae ==="
  $VM_SSH "cd $VM_CHANNEL_DIR && guix build -L . -f custom/packages/vicinae.scm 2>&1" || true
}

step_build_zapret2() {
  echo "=== Building zapret2 ==="
  $VM_SSH "cd $VM_CHANNEL_DIR && guix build -L . -f custom/packages/zapret2.scm 2>&1" || true
}

step_build_proxypilot() {
  echo "=== Building proxypilot ==="
  $VM_SSH "cd $VM_CHANNEL_DIR && guix build -L . -f custom/packages/proxypilot.scm 2>&1" || true
}

step_build_sing_box() {
  echo "=== Building sing-box ==="
  $VM_SSH "cd $VM_CHANNEL_DIR && guix build -L . -f custom/packages/sing-box.scm 2>&1" || true
}

step_build_v2raya() {
  echo "=== Building v2raya ==="
  $VM_SSH "cd $VM_CHANNEL_DIR && guix build -L . -f custom/packages/v2raya.scm 2>&1" || true
}

step_build_tailscale() {
  echo "=== Building tailscale ==="
  $VM_SSH "cd $VM_CHANNEL_DIR && guix build -L . -f custom/packages/tailscale.scm 2>&1" || true
}

step_build_ollama() {
  echo "=== Building ollama ==="
  $VM_SSH "cd $VM_CHANNEL_DIR && guix build -L . -f custom/packages/ollama.scm 2>&1" || true
}

step_reconfigure() {
  echo "=== Reconfiguring system ==="
  $VM_SSH "sudo cp /tmp/config.scm /etc/config.scm && sudo guix system reconfigure /etc/config.scm -L $VM_CHANNEL_DIR 2>&1"
}

case "${1:-all}" in
  sync) step_sync ;;
  vicinae) step_build_vicinae ;;
  zapret2) step_build_zapret2 ;;
  proxypilot) step_build_proxypilot ;;
  sing-box) step_build_sing_box ;;
  v2raya) step_build_v2raya ;;
  tailscale) step_build_tailscale ;;
  ollama) step_build_ollama ;;
  reconfigure) step_reconfigure ;;
  all)
    step_sync
    step_build_vicinae
    step_build_zapret2
    step_build_proxypilot
    step_build_sing_box
    step_build_v2raya
    step_build_tailscale
    step_build_ollama
    step_reconfigure
    ;;
  *)
    echo "Usage: $0 {sync|vicinae|zapret2|proxypilot|sing-box|v2raya|tailscale|ollama|reconfigure|all}"
    ;;
esac
