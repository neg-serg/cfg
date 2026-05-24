#!/usr/bin/env bash
# NixOS VM — full automated deployment using nixpkgs VM runner (not disko).
# One-command: builds closure, creates disk, boots VM, provisions dotfiles + secrets.
# Usage:
#   ./deploy-vm.sh                    # headless (serial console only)
#   HEADLESS=0 ./deploy-vm.sh         # graphical (virgl + SPICE)
#   VM_RAM=16384 VM_CPUS=8 ./deploy-vm.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$PROJECT_DIR/../.." && pwd)"

# ── Configuration ────────────────────────────────────────────────────────
VM_NAME="${VM_NAME:-nixos}"
DISK_IMAGE="${DISK_IMAGE:-${PROJECT_DIR}/nixos.qcow2}"
VM_RAM="${VM_RAM:-24576}"          # 24G default
VM_CPUS="${VM_CPUS:-4}"
SSH_PORT="${SSH_PORT:-2222}"
SSH_KEY="${SSH_KEY:-${HOME}/.ssh/id_ed25519}"
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -p ${SSH_PORT}"
SCP_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -P ${SSH_PORT}"
DOTFILES_DIR="${DOTFILES_DIR:-${REPO_ROOT}/dotfiles}"
AGE_KEY_PATH="${AGE_KEY_PATH:-${HOME}/.config/age/key.txt}"
GOPASS_DIR="${GOPASS_DIR:-${HOME}/.local/share/pass}"
HEADLESS="${HEADLESS:-1}"          # 1=serial console, 0=SPICE graphics
NEG_PASS="${NEG_PASS:-nixos}"      # password for neg user

red()   { echo -e "\033[31m$*\033[0m" >&2; }
green() { echo -e "\033[32m$*\033[0m"; }
cyan()  { echo -e "\033[36m$*\033[0m"; }
bold()  { echo -e "\033[1m$*\033[0m"; }

cleanup() {
    if [ "${KEEP_RUNNING:-1}" != "0" ]; then
        kill "${QEMU_PID:-}" 2>/dev/null || true
        wait "${QEMU_PID:-}" 2>/dev/null || true
    fi
}
trap cleanup EXIT

# ─── Step 1: Prerequisites ───────────────────────────────────────────────
bold "╔══════════════════════════════════════════════╗"
bold "║  NixOS VM — Full Automated Deployment       ║"
bold "╚══════════════════════════════════════════════╝"
echo ""

cyan "── Step 1/5: Checking prerequisites ──"

command -v nix >/dev/null 2>&1 || { red "nix not found"; exit 1; }
command -v qemu-system-x86_64 >/dev/null 2>&1 || { red "qemu not found"; exit 1; }
command -v ssh >/dev/null 2>&1 || { red "ssh not found"; exit 1; }

# Dotfiles
if [ -d "$DOTFILES_DIR" ]; then
    green "  Dotfiles: $DOTFILES_DIR"
else
    cyan "  Dotfiles not found — skipping chezmoi"
    DOTFILES_DIR=""
fi

# Age key
if [ -f "$AGE_KEY_PATH" ]; then
    green "  Age key: $AGE_KEY_PATH"
else
    cyan "  Age key not found — secrets won't be available in VM"
    AGE_KEY_PATH=""
fi

# Gopass
if [ -d "$GOPASS_DIR/.git" ]; then
    green "  Gopass: $GOPASS_DIR"
else
    cyan "  Gopass store not found — skipping password store"
    GOPASS_DIR=""
fi

green "  Prerequisites OK"

# ─── Step 2: Build system closure ─────────────────────────────────────────
cyan "── Step 2/5: Building NixOS system ──"

cd "$PROJECT_DIR"

VM_RUNNER=$(nix build "path:${PROJECT_DIR}#nixosConfigurations.nixos.config.system.build.vm" \
  --print-out-paths --no-link 2>/dev/null | grep -v error | tail -1)
if [ -z "$VM_RUNNER" ] || [ ! -d "$VM_RUNNER" ]; then
    red "System build failed"
    exit 1
fi
green "  VM runner: $VM_RUNNER"

# Get the system closure path for provisioning
SYSTEM_CLOSURE=$(readlink -f "$VM_RUNNER/../.." 2>/dev/null || echo "")
if [ -z "$SYSTEM_CLOSURE" ]; then
    SYSTEM_CLOSURE=$(nix eval "path:${PROJECT_DIR}#nixosConfigurations.nixos.config.system.build.toplevel" 2>/dev/null)
fi
green "  System: $SYSTEM_CLOSURE"

# ─── Step 3: Prepare disk ─────────────────────────────────────────────────
cyan "── Step 3/5: Preparing disk image ──"

# VM runner auto-creates the disk if it doesn't exist — just ensure the path is ready
if [ -f "$DISK_IMAGE" ]; then
    green "  Using existing: $DISK_IMAGE ($(du -h "$DISK_IMAGE" | cut -f1))"
else
    cyan "  Disk will be created by VM runner at $DISK_IMAGE"
fi

# ─── Step 4: Boot VM ──────────────────────────────────────────────────────
cyan "── Step 4/5: Booting VM ──"

# Kill any previous VM
kill "$(cat /tmp/nixos-vm-pid 2>/dev/null)" 2>/dev/null || true
rm -f /tmp/nixos-vm-pid

VM_BOOT_LOG=/tmp/nixos-vm-boot.log
rm -f "$VM_BOOT_LOG"

# Configure QEMU based on display mode
if [[ "$HEADLESS" == "1" ]]; then
    cyan "  Mode: headless (serial console, SSH port $SSH_PORT)"
    QEMU_OPTS="-nographic -m ${VM_RAM} -smp ${VM_CPUS}"
    QEMU_NET_OPTS="hostfwd=tcp::${SSH_PORT}-:22"
    NIX_DISK_IMAGE="$DISK_IMAGE" \
        QEMU_OPTS="$QEMU_OPTS" \
        QEMU_NET_OPTS="$QEMU_NET_OPTS" \
        "$VM_RUNNER/bin/run-nixos-vm" > "$VM_BOOT_LOG" 2>&1 &
else
    cyan "  Mode: graphical (virgl GPU + SPICE display, port 5900)"
    cyan "  Connect: remote-viewer spice://127.0.0.1:5900"
    QEMU_OPTS="-m ${VM_RAM} -smp ${VM_CPUS} \
        -device virtio-vga-gl \
        -display egl-headless,rendernode=/dev/dri/renderD128 \
        -spice addr=127.0.0.1,port=5900,disable-ticketing=on"
    QEMU_NET_OPTS="hostfwd=tcp::${SSH_PORT}-:22"
    NIX_DISK_IMAGE="$DISK_IMAGE" \
        QEMU_OPTS="$QEMU_OPTS" \
        QEMU_NET_OPTS="$QEMU_NET_OPTS" \
        LD_LIBRARY_PATH=/usr/lib \
        "$VM_RUNNER/bin/run-nixos-vm" > "$VM_BOOT_LOG" 2>&1 &
fi

QEMU_PID=$!
echo "$QEMU_PID" > /tmp/nixos-vm-pid
green "  QEMU PID: $QEMU_PID"

# ─── Step 5: Wait for SSH ─────────────────────────────────────────────────
cyan "── Step 5/5: Waiting for SSH (max 180s) ──"

SSH_HOST="neg@localhost"
ELAPSED=0
while [ $ELAPSED -lt 180 ]; do
    if ssh $SSH_OPTS -i "$SSH_KEY" "$SSH_HOST" 'echo ok' 2>/dev/null; then
        green "  SSH connected after ${ELAPSED}s"
        break
    fi
    sleep 3
    ELAPSED=$((ELAPSED + 3))
    echo -n "."
done
echo ""

if [ $ELAPSED -ge 180 ]; then
    red "SSH timeout — check $VM_BOOT_LOG"
    grep -v "iPXE\|SeaBIOS\|Booting\|Probing\|mce:" "$VM_BOOT_LOG" 2>/dev/null | tail -20 || true
    exit 1
fi

# ─── Provisioning ──────────────────────────────────────────────────────────
cyan "── Provisioning ──"

PROV_SCRIPT=$(mktemp /tmp/nixos-provision-XXXXXX.sh)
chmod +x "$PROV_SCRIPT"

cat > "$PROV_SCRIPT" << 'PROV_HEADER'
#!/usr/bin/env bash
set -euo pipefail
red()   { echo -e "\033[31m$*" >&2; }
green() { echo -e "\033[32m$*"; }
cyan()  { echo -e "\033[36m$*"; }
HOME_DIR=/home/neg
PROV_HEADER

# ── Age key ──
if [ -n "$AGE_KEY_PATH" ] && [ -f "$AGE_KEY_PATH" ]; then
    scp $SCP_OPTS -i "$SSH_KEY" "$AGE_KEY_PATH" "$SSH_HOST:/tmp/age-key.txt" 2>/dev/null
    cat >> "$PROV_SCRIPT" << 'PROV_AGE'
cyan "── Setting up age key ──"
mkdir -p "$HOME_DIR/.config/age"
cp /tmp/age-key.txt "$HOME_DIR/.config/age/key.txt"
chmod 600 "$HOME_DIR/.config/age/key.txt"
chown -R neg:users "$HOME_DIR/.config/age"
green "  Age key deployed"
PROV_AGE
fi

# ── Chezmoi from local dotfiles ──
if [ -n "$DOTFILES_DIR" ] && [ -d "$DOTFILES_DIR" ]; then
    DOT_TARBALL=/tmp/nixos-dotfiles.tar.gz
    tar czf "$DOT_TARBALL" -C "$(dirname "$DOTFILES_DIR")" "$(basename "$DOTFILES_DIR")" 2>/dev/null

    cat >> "$PROV_SCRIPT" << 'PROV_CHEZMOI'
cyan "── Setting up chezmoi from local dotfiles ──"
if [ -f /tmp/dotfiles.tar.gz ]; then
    mkdir -p "$HOME_DIR/.local/share"
    tar xzf /tmp/dotfiles.tar.gz -C "$HOME_DIR/.local/share/"
    chown -R neg:users "$HOME_DIR/.local/share/dotfiles"
    chezmoi init --apply --source "$HOME_DIR/.local/share/dotfiles" \
        --destination "$HOME_DIR" 2>&1 || true
    green "  chezmoi dotfiles applied"
else
    cyan "  dotfiles tarball not found — skipped"
fi
PROV_CHEZMOI

    scp $SCP_OPTS -i "$SSH_KEY" "$DOT_TARBALL" "$SSH_HOST:/tmp/dotfiles.tar.gz" 2>/dev/null
    rm -f "$DOT_TARBALL"
fi

# ── Gopass ──
if [ -n "$GOPASS_DIR" ] && [ -d "$GOPASS_DIR/.git" ]; then
    PASS_TARBALL=/tmp/nixos-gopass.tar.gz
    tar czf "$PASS_TARBALL" -C "$(dirname "$GOPASS_DIR")" "$(basename "$GOPASS_DIR")" 2>/dev/null

    cat >> "$PROV_SCRIPT" << 'PROV_GOPASS'
cyan "── Setting up gopass password store ──"
if [ -f /tmp/gopass.tar.gz ]; then
    mkdir -p "$HOME_DIR/.local/share"
    tar xzf /tmp/gopass.tar.gz -C "$HOME_DIR/.local/share/"
    chown -R neg:users "$HOME_DIR/.local/share/pass"
    gopass setup --crypto age 2>/dev/null || true
    green "  gopass store deployed"
fi
PROV_GOPASS

    scp $SCP_OPTS -i "$SSH_KEY" "$PASS_TARBALL" "$SSH_HOST:/tmp/gopass.tar.gz" 2>/dev/null
    rm -f "$PASS_TARBALL"
fi

# ── Verification ──
cat >> "$PROV_SCRIPT" << 'PROV_VERIFY'
cyan "── Verification ──"
echo "  System:   $(uname -r)"
echo "  Hostname: $(hostname)"
echo "  NixOS:    $(nixos-version)"

for tool in chezmoi gopass age git; do
    which "$tool" >/dev/null 2>&1 && echo "  ✅ $tool" || echo "  ⚠️  $tool (not found)"
done

# GPU check
if [ -e /dev/dri/renderD128 ]; then
    echo "  ✅ GPU: /dev/dri/renderD128 present"
else
    echo "  ℹ️  GPU: no render node (headless mode)"
fi

# Services check
for svc in sshd greetd flatpak-system-helper mpd; do
    systemctl is-active "$svc" >/dev/null 2>&1 && echo "  ✅ $svc" || echo "  ⚠️  $svc inactive"
done

echo ""
green "╔══════════════════════════════════════════════╗"
green "║  VM deployment complete!                    ║"
green "╚══════════════════════════════════════════════╝"
PROV_VERIFY

# Copy and run provision script
scp $SCP_OPTS -i "$SSH_KEY" "$PROV_SCRIPT" "$SSH_HOST:/tmp/provision.sh" 2>/dev/null
ssh $SSH_OPTS -i "$SSH_KEY" -t "$SSH_HOST" "bash /tmp/provision.sh" 2>&1 || {
    red "Provisioning had warnings — check output above"
}
rm -f "$PROV_SCRIPT"

# ─── Done ──────────────────────────────────────────────────────────────────
echo ""
bold "╔══════════════════════════════════════════════╗"
bold "║  Deployment Complete                         ║"
bold "╠══════════════════════════════════════════════╣"
bold "║  SSH:   ssh -p ${SSH_PORT} neg@localhost       ║"
[[ "$HEADLESS" != "1" ]] && bold "║  GUI:   remote-viewer spice://127.0.0.1:5900  ║"
bold "║  Stop:  kill ${QEMU_PID}                     ║"
bold "╚══════════════════════════════════════════════╝"
echo ""

if [ "${KEEP_RUNNING:-1}" = "1" ]; then
    cyan "VM is running. Press Ctrl-C to stop."
    wait "$QEMU_PID" 2>/dev/null || true
fi
