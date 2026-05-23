#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$PROJECT_DIR/../.." && pwd)"
VM_NAME="${VM_NAME:-nixos}"
DISK_IMAGE="${DISK_IMAGE:-${PROJECT_DIR}/nixos.qcow2}"
VM_RAM="${VM_RAM:-24576}"
VM_CPUS="${VM_CPUS:-8}"
SSH_PORT="${SSH_PORT:-2222}"
SSH_KEY="${SSH_KEY:-${HOME}/.ssh/id_ed25519}"
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -p ${SSH_PORT}"
DOTFILES_DIR="${DOTFILES_DIR:-${REPO_ROOT}/dotfiles}"
AGE_KEY="${AGE_KEY:-${AGE_KEY_PATH:-${HOME}/.config/age/keys.txt}}"
GOPASS_DIR="${GOPASS_DIR:-${HOME}/.local/share/pass}"
HEADLESS="${HEADLESS:-0}"

red()   { echo -e "\033[31m$*\033[0m" >&2; }
green() { echo -e "\033[32m$*\033[0m"; }
cyan()  { echo -e "\033[36m$*\033[0m"; }
bold()  { echo -e "\033[1m$*\033[0m"; }

cleanup() {
    kill "${QEMU_PID:-}" 2>/dev/null || true
    wait "${QEMU_PID:-}" 2>/dev/null || true
}
trap cleanup EXIT

# ─── Step 1: Prerequisites ───────────────────────────────────────────────
bold "╔══════════════════════════════════════════════╗"
bold "║  NixOS VM — Full Automated Deployment       ║"
bold "╚══════════════════════════════════════════════╝"
echo ""

cyan "── Step 1/7: Checking prerequisites ──"

command -v nix >/dev/null 2>&1 || { red "nix not found"; exit 1; }
command -v qemu-system-x86_64 >/dev/null 2>&1 || { red "qemu not found"; exit 1; }

# Dotfiles
if [ -d "$DOTFILES_DIR" ]; then
    green "  Dotfiles: $DOTFILES_DIR"
else
    cyan "  Dotfiles not found at $DOTFILES_DIR — skipping chezmoi"
    DOTFILES_DIR=""
fi

# Age key
if [ -f "$AGE_KEY" ]; then
    green "  Age key: $AGE_KEY"
else
    cyan "  Age key not found — secrets won't be available in VM"
    AGE_KEY=""
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
cyan "── Step 2/7: Building NixOS system closure ──"
cd "$PROJECT_DIR"

nix flake check --no-build 2>/dev/null || { red "Flake check failed"; exit 1; }

CLOSURE=$(nix build "path:${PROJECT_DIR}#nixosConfigurations.nixos.config.system.build.toplevel" \
  --print-out-paths --no-link 2>/dev/null | tail -1)
if [ -z "$CLOSURE" ] || [ ! -d "$CLOSURE" ]; then
    red "System build failed"
    exit 1
fi
green "  System closure: $CLOSURE"

# ─── Step 3: Prepare disk ─────────────────────────────────────────────────
cyan "── Step 3/7: Preparing disk image ──"

if [ ! -f "$DISK_IMAGE" ]; then
    DISKO_IMG=$(nix build "path:${PROJECT_DIR}#nixosConfigurations.nixos.config.system.build.diskoImages" \
      --print-out-paths --no-link 2>/dev/null | tail -1)
    if [ -z "$DISKO_IMG" ] || [ ! -d "$DISKO_IMG" ]; then
        red "Disko image build failed"
        exit 1
    fi
    qemu-img convert -f raw -O qcow2 -c "$DISKO_IMG/sda.raw" "$DISK_IMAGE"
    green "  Created partitioned qcow2: $DISK_IMAGE"
else
    green "  Using existing: $DISK_IMAGE"
fi

# ─── Step 4: Build VM runner ──────────────────────────────────────────────
cyan "── Step 4/7: Building VM runner ──"

VM_RUNNER=$(nix build "path:${PROJECT_DIR}#nixosConfigurations.nixos.config.system.build.vm" \
  --print-out-paths --no-link 2>/dev/null | tail -1)
if [ -z "$VM_RUNNER" ]; then
    red "VM runner build failed"
    exit 1
fi
green "  VM runner: $VM_RUNNER"

# ─── Step 5: Boot VM ──────────────────────────────────────────────────────
cyan "── Step 5/7: Booting VM ──"

kill "$(cat /tmp/nixos-vm-pid 2>/dev/null)" 2>/dev/null || true
rm -f /tmp/nixos-vm-pid

VM_BOOT_LOG=/tmp/nixos-vm-boot.log

if [[ "$HEADLESS" == "1" ]]; then
    export QEMU_OPTS="-m ${VM_RAM} -smp ${VM_CPUS}"
    export QEMU_NET_OPTS="hostfwd=tcp::${SSH_PORT}-:22"
    cyan "  Launching QEMU headless (${VM_RAM}M RAM, ${VM_CPUS} CPUs)..."
    $VM_RUNNER/bin/run-nixos-vm > "$VM_BOOT_LOG" 2>&1 &
else
    export QEMU_OPTS="-m ${VM_RAM} -smp ${VM_CPUS} -vga virtio -display gtk,gl=off,grab-on-hover=on"
    export QEMU_NET_OPTS="hostfwd=tcp::${SSH_PORT}-:22"
    cyan "  Launching QEMU with virgl GPU (${VM_RAM}M RAM, ${VM_CPUS} CPUs)..."
    $VM_RUNNER/bin/run-nixos-vm > "$VM_BOOT_LOG" 2>&1 &
fi

QEMU_PID=$!
echo "$QEMU_PID" > /tmp/nixos-vm-pid

# Wait for SSH
cyan "── Step 6/7: Waiting for SSH (max 120s) ──"

SSH_HOST="root@localhost"
ELAPSED=0
while [ $ELAPSED -lt 120 ]; do
    if ssh $SSH_OPTS -i "$SSH_KEY" "$SSH_HOST" 'echo ok' 2>/dev/null; then
        green "  SSH connected after ${ELAPSED}s"
        break
    fi
    sleep 3
    ELAPSED=$((ELAPSED + 3))
    echo -n "."
done
echo ""

if [ $ELAPSED -ge 120 ]; then
    red "SSH timeout — check $VM_BOOT_LOG"
    grep -v "iPXE\|SeaBIOS\|Booting\|Probing\|mce:" "$VM_BOOT_LOG" 2>/dev/null | tail -20 || true
    exit 1
fi

# ─── Step 7: Provision ────────────────────────────────────────────────────
cyan "── Step 7/7: Provisioning VM ──"

PROV_SCRIPT=$(mktemp /tmp/nixos-provision-XXXXXX.sh)
chmod +x "$PROV_SCRIPT"

# Build the provision script with actual values embedded
cat > "$PROV_SCRIPT" << 'PROV_HEADER'
#!/usr/bin/env bash
set -euo pipefail
red()   { echo -e "\033[31m$*\033[0m" >&2; }
green() { echo -e "\033[32m$*\033[0m"; }
cyan()  { echo -e "\033[36m$*\033[0m"; }
HOME_DIR=/home/neg
PROV_HEADER

# ── Chezmoi from local dotfiles ──
if [ -n "$DOTFILES_DIR" ] && [ -d "$DOTFILES_DIR" ]; then
    DOT_TARBALL=/tmp/nixos-dotfiles.tar.gz
    tar czf "$DOT_TARBALL" -C "$(dirname "$DOTFILES_DIR")" "$(basename "$DOTFILES_DIR")"
    
    cat >> "$PROV_SCRIPT" << PROV_CHEZMOI
cyan "── Setting up chezmoi from local dotfiles ──"
mkdir -p "\$HOME_DIR/.local/share"
if [ -f /tmp/dotfiles.tar.gz ]; then
    tar xzf /tmp/dotfiles.tar.gz -C "\$HOME_DIR/.local/share/"
    chown -R neg:users "\$HOME_DIR/.local/share/dotfiles"
    chezmoi init --apply --source "\$HOME_DIR/.local/share/dotfiles" --destination "\$HOME_DIR" 2>&1 || {
        red "  chezmoi init had warnings — continuing anyway"
    }
    # Copy quickshell greeter directly (chezmoi may fail on gopass templates)
    if [ -d "\$HOME_DIR/.local/share/dotfiles/dot_config/quickshell" ]; then
        mkdir -p "\$HOME_DIR/.config/quickshell"
        cp -r "\$HOME_DIR/.local/share/dotfiles/dot_config/quickshell/"* "\$HOME_DIR/.config/quickshell/"
        chown -R neg:users "\$HOME_DIR/.config/quickshell"
    fi
    green "  chezmoi dotfiles applied from local source"
else
    red "  dotfiles tarball not found — skipped"
fi
PROV_CHEZMOI

    scp $SSH_OPTS -i "$SSH_KEY" "$DOT_TARBALL" "$SSH_HOST:/tmp/dotfiles.tar.gz" 2>/dev/null
    rm -f "$DOT_TARBALL"
else
    cat >> "$PROV_SCRIPT" << 'PROV_NO_CHEZMOI'
cyan "── No dotfiles source — skipping chezmoi ──"
PROV_NO_CHEZMOI
fi

# ── Gopass from local store ──
if [ -n "$GOPASS_DIR" ] && [ -d "$GOPASS_DIR/.git" ]; then
    PASS_TARBALL=/tmp/nixos-gopass.tar.gz
    tar czf "$PASS_TARBALL" -C "$(dirname "$GOPASS_DIR")" "$(basename "$GOPASS_DIR")"
    
    cat >> "$PROV_SCRIPT" << PROV_GOPASS
cyan "── Setting up gopass password store ──"
if [ -f /tmp/gopass.tar.gz ]; then
    mkdir -p "\$HOME_DIR/.local/share"
    tar xzf /tmp/gopass.tar.gz -C "\$HOME_DIR/.local/share/"
    chown -R neg:users "\$HOME_DIR/.local/share/pass"
    gopass setup --crypto age 2>/dev/null || true
    green "  gopass store deployed"
else
    cyan "  gopass tarball not found — skipped"
fi
PROV_GOPASS

    scp $SSH_OPTS -i "$SSH_KEY" "$PASS_TARBALL" "$SSH_HOST:/tmp/gopass.tar.gz" 2>/dev/null
    rm -f "$PASS_TARBALL"
else
    cat >> "$PROV_SCRIPT" << 'PROV_NO_GOPASS'
cyan "── No gopass store — skipping password store ──"
PROV_NO_GOPASS
fi

# ── Verification ──
cat >> "$PROV_SCRIPT" << 'PROV_VERIFY'
cyan "── Verification ──"
echo "  System:   $(uname -r)"
echo "  Hostname: $(hostname)"
echo "  Shell:    $(basename $SHELL 2>/dev/null || echo 'n/a')"

for tool in chezmoi gopass age zsh vicinae zen-browser quickshell; do
    which "$tool" >/dev/null 2>&1 && echo "  ✅ $tool" || echo "  ⚠️  $tool (not found)"
done

# GPU check
if command -v glxinfo >/dev/null 2>&1; then
    glxinfo -B 2>/dev/null | grep -E "Device|OpenGL.renderer|OpenGL.version" | head -5 || echo "  ℹ️  GPU: no display available"
elif [ -e /dev/dri/renderD128 ]; then
    echo "  ✅ GPU: /dev/dri/renderD128 present"
else
    echo "  ⚠️  GPU: no render node found"
fi

echo ""
[[ "$HEADLESS" != "1" ]] && echo "  🖥  greetd + quickshell greeter should be visible in QEMU window"
green "╔══════════════════════════════════════════════╗"
green "║  Provisioning complete!                     ║"
green "╚══════════════════════════════════════════════╝"
PROV_VERIFY

# Copy and run provision script
scp $SSH_OPTS -i "$SSH_KEY" "$PROV_SCRIPT" "$SSH_HOST:/tmp/provision.sh" 2>/dev/null
ssh $SSH_OPTS -i "$SSH_KEY" -t "$SSH_HOST" "bash /tmp/provision.sh" 2>&1 || {
    red "Provisioning had errors — check output above"
}
rm -f "$PROV_SCRIPT"

# ─── Done ──────────────────────────────────────────────────────────────────
echo ""
bold "╔══════════════════════════════════════════════╗"
bold "║  Deployment Complete                         ║"
bold "╠══════════════════════════════════════════════╣"
bold "║  SSH:   ssh -p ${SSH_PORT} root@localhost       ║"
[[ "$HEADLESS" != "1" ]] && bold "║  GUI:   QEMU window (greetd + quickshell)    ║"
bold "║  Stop:  kill ${QEMU_PID}                     ║"
bold "╚══════════════════════════════════════════════╝"
echo ""

if [ "${KEEP_RUNNING:-1}" = "1" ]; then
    cyan "VM is running. Press Ctrl-C to stop."
    wait "$QEMU_PID" 2>/dev/null || true
fi
