#!/bin/bash
# Batch install all Guix packages on host
# Run: bash scripts/guix-host-install.sh

set -e
export PATH="$HOME/.config/guix/current/bin:$PATH"

restart_daemon() {
  sudo pkill guix-daemon 2>/dev/null || true
  sleep 1
  sudo guix-daemon --build-users-group=guixbuild \
    --substitute-urls=https://bordeaux.guix.gnu.org &
  sleep 3
}

install_batch() {
  local name="$1"; shift
  echo "=== $(date +%H:%M) $name ==="
  restart_daemon
  guix install --fallback "$@" 2>&1 | tail -3
  echo "Total: $(guix package -I | wc -l)"
}

# Will be called by user
echo "Usage: bash scripts/guix-host-install.sh"
echo "Starting daemon..."
restart_daemon
echo "Ready. $(guix package -I | wc -l) packages installed."
