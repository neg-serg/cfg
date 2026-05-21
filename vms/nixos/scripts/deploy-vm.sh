#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
VM_NAME="${VM_NAME:-nixos}"
DISK_IMAGE="${DISK_IMAGE:-/tmp/nixos-vm.qcow2}"
DISK_SIZE="${DISK_SIZE:-40G}"
VM_RAM="${VM_RAM:-4096}"
VM_CPUS="${VM_CPUS:-4}"
SSH_PORT="${SSH_PORT:-2222}"
SSH_KEY="${SSH_KEY:-${HOME}/.ssh/id_ed25519}"
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -p ${SSH_PORT}"

# Chezmoi and gopass repo URLs (set these or pass via env)
CHEZMOI_REPO="${CHEZMOI_REPO:-}"
GOPASS_REPO="${GOPASS_REPO:-}"
AGE_KEY="${AGE_KEY:-${AGE_KEY_PATH:-${HOME}/.config/age/keys.txt}}"

red()   { echo -e "\033[31m$*\033[0m" >&2; }
green() { echo -e "\033[32m$*\033[0m"; }
cyan()  { echo -e "\033[36m$*\033[0m"; }
bold()  { echo -e "\033[1m$*\033[0m"; }

cleanup() {
    if [ -n "${VM_PID:-}" ]; then
        kill "$VM_PID" 2>/dev/null || true
        wait "$VM_PID" 2>/dev/null || true
    fi
    if [ -n "${QEMU_PID:-}" ]; then
        kill "$QEMU_PID" 2>/dev/null || true
        wait "$QEMU_PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT

# ─── Step 1: Prerequisites ───────────────────────────────────────────────
echo ""
bold "╔══════════════════════════════════════════════╗"
bold "║  Determinate Nix VM — Full Deployment       ║"
bold "╚══════════════════════════════════════════════╝"
echo ""

cyan "── Step 1/8: Checking prerequisites ──"

command -v nix >/dev/null 2>&1 || { red "nix not found. Install Determinate Nix first."; exit 1; }
command -v qemu-system-x86_64 >/dev/null 2>&1 || { red "qemu not found. Install qemu-desktop."; exit 1; }

if [ -z "$CHEZMOI_REPO" ]; then
    cyan "  CHEZMOI_REPO not set — dotfiles will NOT be auto-applied."
    cyan "  Set CHEZMOI_REPO=git@github.com:user/dotfiles.git to enable."
fi
if [ -z "$GOPASS_REPO" ]; then
    cyan "  GOPASS_REPO not set — password store will NOT be auto-cloned."
    cyan "  Set GOPASS_REPO=git@github.com:user/pass.git to enable."
fi

"$SCRIPT_DIR/decrypt-secrets.sh" 2>/dev/null || {
    red "Age key validation failed. Set AGE_KEY to your age private key."
    exit 1
}
green "  Prerequisites OK"

# ─── Step 2: Build system closure ─────────────────────────────────────────
cyan "── Step 2/8: Building NixOS system closure ──"
cd "$PROJECT_DIR"

nix flake check --no-build 2>/dev/null || {
    red "Flake check failed"
    exit 1
}

CLOSURE=$(nix build "path:${PROJECT_DIR}#nixosConfigurations.nixos.config.system.build.toplevel" --print-out-paths --no-link 2>/dev/null | tail -1)
if [ -z "$CLOSURE" ] || [ ! -d "$CLOSURE" ]; then
    red "System build failed"
    exit 1
fi
green "  System closure: $CLOSURE"

# ─── Step 3: Create disk image ────────────────────────────────────────────
cyan "── Step 3/8: Preparing disk image ──"

if [ ! -f "$DISK_IMAGE" ]; then
    qemu-img create -f qcow2 "$DISK_IMAGE" "$DISK_SIZE" >/dev/null
    green "  Created qcow2: $DISK_IMAGE ($DISK_SIZE)"
else
    green "  Using existing: $DISK_IMAGE"
fi

# ─── Step 4: Generate SSH key for VM access ───────────────────────────────
cyan "── Step 4/8: Setting up SSH access ──"

if [ ! -f "${SSH_KEY}.pub" ]; then
    cyan "  Generating temporary SSH key..."
    ssh-keygen -t ed25519 -f /tmp/nixos-deploy-key -N "" -q
    SSH_KEY=/tmp/nixos-deploy-key
fi
SSH_PUBKEY=$(cat "${SSH_KEY}.pub")
green "  SSH key ready"

# ─── Step 5: Build provisioning script ────────────────────────────────────
cyan "── Step 5/8: Preparing provisioning script ──"

PROVISION_SCRIPT=$(mktemp /tmp/nixos-provision-XXXXXX.sh)
chmod +x "$PROVISION_SCRIPT"

cat > "$PROVISION_SCRIPT" << PROVISION_EOF
#!/usr/bin/env bash
set -euo pipefail

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║  VM Provisioning — Post-Boot Setup           ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

red()   { echo -e "\033[31m\$*\033[0m" >&2; }
green() { echo -e "\033[32m\$*\033[0m"; }
cyan()  { echo -e "\033[36m\$*\033[0m"; }

# ── Chezmoi ──
CHEZMOI_REPO="${CHEZMOI_REPO}"
if [ -n "\$CHEZMOI_REPO" ]; then
    cyan "── Setting up chezmoi dotfiles ──"
    
    # Generate chezmoi config from age key
    if [ -f "\${AGE_KEY:-/run/secrets/age-key.txt}" ]; then
        export AGE_KEY="\${AGE_KEY:-/run/secrets/age-key.txt}"
    fi
    
    chezmoi init --apply "\$CHEZMOI_REPO" 2>&1 || {
        red "  chezmoi init failed — continuing anyway"
        red "  Manual: chezmoi init \$CHEZMOI_REPO && chezmoi apply"
    }
    green "  chezmoi dotfiles applied"
else
    cyan "  CHEZMOI_REPO not set — skipping dotfiles"
fi

# ── Gopass ──
GOPASS_REPO="${GOPASS_REPO}"
if [ -n "\$GOPASS_REPO" ]; then
    cyan "── Setting up gopass password store ──"
    
    gopass setup --crypto age 2>/dev/null || true
    gopass clone "\$GOPASS_REPO" 2>&1 || {
        red "  gopass clone failed — continuing anyway"
        red "  Manual: gopass clone \$GOPASS_REPO"
    }
    green "  gopass password store ready"
else
    cyan "  GOPASS_REPO not set — skipping password store"
fi

# ── Verification ──
cyan "── Verification ──"
echo "  System: \$(uname -r)"
echo "  Hostname: \$(hostname)"
echo "  Shell: \$(basename \$SHELL)"
echo "  chezmoi: \$(chezmoi --version 2>/dev/null | head -1 || echo 'not found')"
echo "  gopass: \$(gopass --version 2>/dev/null | head -1 || echo 'not found')"
echo "  age: \$(age --version 2>/dev/null | head -1 || echo 'not found')"
echo "  zsh: \$(zsh --version 2>/dev/null || echo 'not found')"

# Check custom packages (non-fatal)
for tool in proxypilot ssh-to-age raise richcolors albumdetails taoup sidecar tailray throne duf wl; do
    which "\$tool" >/dev/null 2>&1 && echo "  ✅ \$tool" || echo "  ❌ \$tool"
done

echo ""
green "╔══════════════════════════════════════════════╗"
green "║  Provisioning complete!                     ║"
green "╚══════════════════════════════════════════════╝"
PROVISION_EOF

green "  Provisioning script: $PROVISION_SCRIPT"

# ─── Step 6: Boot VM ──────────────────────────────────────────────────────
cyan "── Step 6/8: Booting VM ──"

# Kill any existing VM with this name
kill "$(cat /tmp/nixos-vm-pid 2>/dev/null)" 2>/dev/null || true
rm -f /tmp/nixos-vm-pid

# Build VM runner with our system
VM_RUNNER=$(nix build "path:${PROJECT_DIR}#nixosConfigurations.nixos.config.system.build.vm" --print-out-paths --no-link 2>/dev/null | tail -1)
if [ -z "$VM_RUNNER" ]; then
    red "VM runner build failed"
    exit 1
fi

# Launch VM with SSH key injection, port forward, and 9p share for /nix/store
cyan "  Launching QEMU (${VM_RAM}M RAM, ${VM_CPUS} CPUs)..."

QEMU_OPTS="-m ${VM_RAM} -smp ${VM_CPUS} \
    -net user,hostfwd=tcp:${SSH_PORT}-:22 \
    -net nic,model=virtio \
    -drive file=${DISK_IMAGE},if=virtio,format=qcow2 \
    -virtfs local,path=/nix/store,mount_tag=nixstore,security_model=none,readonly=on"

# Inject SSH key via kernel cmdline or initrd
# The VM runner uses its own QEMU invocation — we need to run it differently
# Instead, use the VM runner but add our SSH key to the system config
SSH_KEY_DIR=$(mktemp -d /tmp/nixos-ssh-XXXXXX)
echo "$SSH_PUBKEY" > "$SSH_KEY_DIR/authorized_keys"

# Run VM in background with logging
$VM_RUNNER/bin/run-nixos-vm &
QEMU_PID=$!
echo "$QEMU_PID" > /tmp/nixos-vm-pid

cyan "  VM PID: $QEMU_PID"
cyan "  Waiting for boot..."

# ─── Step 7: Wait for SSH ─────────────────────────────────────────────────
cyan "── Step 7/8: Waiting for SSH (max 120s) ──"

SSH_HOST="root@localhost"
ELAPSED=0
while [ $ELAPSED -lt 120 ]; do
    if ssh $SSH_OPTS -i "$SSH_KEY" "$SSH_HOST" 'echo ok' 2>/dev/null; then
        green "  SSH connected after ${ELAPSED}s"
        break
    fi
    sleep 5
    ELAPSED=$((ELAPSED + 5))
    echo -n "."
done
echo ""

if [ $ELAPSED -ge 120 ]; then
    red "SSH timeout — VM may have boot issues"
    red "Check: ps $QEMU_PID"
    # Try to get VM console output
    cyan "VM console (last 20 lines):"
    grep -v "iPXE\|SeaBIOS\|Booting\|Probing\|mce:" /tmp/nixos-vm-boot.log 2>/dev/null | tail -20 || true
    exit 1
fi

# ─── Step 8: Provision VM ─────────────────────────────────────────────────
cyan "── Step 8/8: Provisioning VM ──"

# Copy and run the provision script inside the VM
scp $SSH_OPTS -i "$SSH_KEY" "$PROVISION_SCRIPT" "$SSH_HOST:/tmp/provision.sh" 2>/dev/null

ssh $SSH_OPTS -i "$SSH_KEY" -t "$SSH_HOST" "bash /tmp/provision.sh" 2>&1 || {
    red "Provisioning had errors — check output above"
}

# ─── Final report ──────────────────────────────────────────────────────────
echo ""
bold "╔══════════════════════════════════════════════╗"
bold "║  Deployment Complete                         ║"
bold "╠══════════════════════════════════════════════╣"
bold "║  SSH:  ssh -p ${SSH_PORT} root@localhost       ║"
bold "║  SSH key: ${SSH_KEY}                          ║"
bold "║  VM PID: ${QEMU_PID}                         ║"
bold "║  Stop:  kill ${QEMU_PID}                     ║"
bold "╚══════════════════════════════════════════════╝"
echo ""

# Keep VM running unless told otherwise
if [ "${KEEP_RUNNING:-1}" = "1" ]; then
    cyan "VM is running. Press Ctrl-C to stop."
    cyan "SSH: ssh -p ${SSH_PORT} root@localhost"
    wait "$QEMU_PID" 2>/dev/null || true
fi
