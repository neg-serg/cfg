#!/usr/bin/env zsh
# test-kvm-deploy-lib.sh — shared functions for KVM deployment testing
# Source this file from test-kvm-deploy.sh

set -euo pipefail

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
readonly QEMU_BIN="${QEMU_BIN:-qemu-system-x86_64}"
readonly OVMF_CODE="${OVMF_CODE:-$(find /usr/share/edk2 -name 'OVMF_CODE.*.fd' \! -name '*secboot*' 2>/dev/null | head -1)}"
readonly OVMF_VARS_TEMPLATE="${OVMF_VARS_TEMPLATE:-$(find /usr/share/edk2 -name 'OVMF_VARS.*.fd' \! -name '*secboot*' 2>/dev/null | head -1)}"
readonly QEMU_IMG="${QEMU_IMG:-qemu-img}"
readonly QEMU_NBD="${QEMU_NBD:-qemu-nbd}"
readonly -a RSYNC_ARGS=(-aH --info=progress2)
SSH_CMD=(ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
    -o ConnectTimeout=5 -o LogLevel=ERROR -o BatchMode=yes)

_ssh_wrapper() {
    local port="$1" host="$2"
    shift 2
    "${SSH_CMD[@]}" -p "$port" "${host}@localhost" "$@"
}

_ssh_with_pass() {
    local port="$1" host="$2"
    shift 2
    if command -v sshpass >/dev/null 2>&1; then
        sshpass -p root "${SSH_CMD[@]}" -p "$port" "${host}@localhost" "$@"
    else
        SSH_ASKPASS_REQUIRE=never SSH_PASSWORD=root \
            "${SSH_CMD[@]}" -o PreferredAuthentications=password \
            -p "$port" "${host}@localhost" "$@" </dev/null
    fi
}

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
LOG_FILE=""

log_init() {
    local dir="${1:-logs}"
    local prefix="${2:-test-kvm-deploy}"
    local ts
    ts=$(date +%Y%m%d-%H%M%S)
    mkdir -p "$dir"
    LOG_FILE="${dir}/${prefix}-${ts}.log"
    exec 3>&1
    exec > >(tee -a "$LOG_FILE") 2>&1
    echo "==> Log: $LOG_FILE"
}

log_phase() { echo ""; echo "==> $1"; }
log_info()  { echo "    $1"; }
log_warn()  { echo "    WARNING: $1" >&2; }
log_error() { echo "    ERROR: $1" >&2; }

# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "error: must run as root (needs mount/losetup/nbd)" >&2
        exit 2
    fi
}

check_rootfs() {
    local rootfs="$1"
    if [[ ! -d "$rootfs/usr/bin" ]]; then
        echo "error: $rootfs is not a CachyOS rootfs (missing usr/bin)" >&2
        echo "  run scripts/bootstrap-cachyos.sh first" >&2
        exit 2
    fi
}

check_kvm() {
    if [[ -r /dev/kvm ]]; then
        echo "    KVM: available"
        return 0
    fi
    echo "    WARNING: /dev/kvm not accessible — falling back to TCG emulation (slow)" >&2
    echo "    To enable KVM: sudo modprobe kvm_intel  # or kvm_amd" >&2
    echo "kvm_disabled" > "/tmp/kvm-deploy-no-kvm"
    return 0
}

check_prereqs() {
    local missing=() missing_pkgs=()
    for cmd in qemu-system-x86_64 qemu-img qemu-nbd parted rsync; do
        command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
    done
    command -v btrfs >/dev/null 2>&1 || { missing+=("btrfs"); missing_pkgs+=("btrfs-progs"); }
    if [[ ! -f "$OVMF_CODE" ]]; then
        missing+=("OVMF_CODE.fd")
        missing_pkgs+=("edk2-ovmf")
    fi
    if (( ${#missing[@]} > 0 )); then
        echo "error: missing prerequisites: ${missing[*]}" >&2
        if (( ${#missing_pkgs[@]} > 0 )); then
            echo "  install: pacman -S ${missing_pkgs[*]}" >&2
        fi
        exit 2
    fi
}

# ---------------------------------------------------------------------------
# VM Image Builder
# ---------------------------------------------------------------------------
build_vm_image() {
    local rootfs="$1"
    local vm_dir="$2"
    local salt_repo="$3"
    local profile="${4:-}"
    local disk="$vm_dir/cachyos.qcow2"
    local mnt="$vm_dir/mnt"
    local ovmf_vars="$vm_dir/OVMF_VARS.fd"
    local disk_size="${KVM_DEPLOY_DISK_SIZE:-20G}"

    log_phase "Creating VM disk image ($disk_size)..."

    mkdir -p "$vm_dir" "$mnt"
    rm -f "$disk"

    # Create qcow2
    qemu-img create -f qcow2 "$disk" "$disk_size" >/dev/null

    # Connect via NBD
    local nbd_dev=""
    for dev in /dev/nbd{0..15}; do
        if [[ ! -b "$dev" ]]; then
            modprobe nbd max_part=8 2>/dev/null || true
            nbd_dev="$dev"
            break
        fi
        # Check if unused (no partitions mounted)
        if ! lsblk -no MOUNTPOINT "${dev}"* 2>/dev/null | grep -q .; then
            nbd_dev="$dev"
            break
        fi
    done
    if [[ -z "$nbd_dev" ]]; then
        echo "error: no free NBD device" >&2
        exit 2
    fi

    qemu-nbd --connect="$nbd_dev" "$disk"
    log_info "Connected $nbd_dev"

    # Partition: 512M EFI + rest btrfs
    log_info "Partitioning..."
    parted -s "$nbd_dev" -- mklabel gpt
    parted -s "$nbd_dev" -- mkpart ESP fat32 1MiB 513MiB
    parted -s "$nbd_dev" -- set 1 esp on
    parted -s "$nbd_dev" -- mkpart root btrfs 513MiB 100%

    partprobe "$nbd_dev"
    local efipart="${nbd_dev}p1"
    local rootpart="${nbd_dev}p2"
    for pdev in "$efipart" "$rootpart"; do
        local timeout=10
        until [[ -b "$pdev" ]] || (( timeout <= 0 )); do
            sleep 0.2
            ((timeout--))
        done
        [[ -b "$pdev" ]] || { echo "error: $pdev did not appear" >&2; exit 2; }
    done

    log_info "Formatting..."
    mkfs.fat -F32 -n EFI "$efipart" >/dev/null
    mkfs.btrfs -f -L cachyos "$rootpart" >/dev/null

    # Create btrfs subvolumes
    log_info "Creating btrfs subvolumes..."
    mount "$rootpart" "$mnt"
    btrfs subvolume create "$mnt/@" >/dev/null
    btrfs subvolume create "$mnt/@home" >/dev/null
    btrfs subvolume create "$mnt/@cache" >/dev/null
    btrfs subvolume create "$mnt/@log" >/dev/null
    umount "$mnt"

    # Mount subvolumes
    log_info "Mounting subvolumes..."
    mount -o "subvol=@,compress=zstd:1,noatime" "$rootpart" "$mnt"
    mkdir -p "$mnt"/{boot,home,var/cache,var/log}
    mount -o "subvol=@home,compress=zstd:1,noatime" "$rootpart" "$mnt/home"
    mount -o "subvol=@cache,compress=zstd:1,noatime" "$rootpart" "$mnt/var/cache"
    mount -o "subvol=@log,compress=zstd:1,noatime" "$rootpart" "$mnt/var/log"

    # Copy rootfs
    log_info "Copying rootfs from $rootfs..."
    rsync "${RSYNC_ARGS[@]}" --exclude='/boot/*' "$rootfs/" "$mnt/"

    # Copy salt repo
    if [[ -n "$salt_repo" && -d "$salt_repo" ]]; then
        log_info "Copying Salt repo from $salt_repo..."
        mkdir -p "$mnt/srv/salt"
        rsync "${RSYNC_ARGS[@]}" --exclude='.git' --exclude='logs/' --exclude='__pycache__/' \
            --exclude='*.pyc' --exclude='.venv/' --exclude='node_modules/' \
            "$salt_repo/" "$mnt/srv/salt/"
    fi

    # Write Salt grains / host identity for this profile
    if [[ -n "$profile" ]]; then
        log_info "Writing Salt grains for profile: $profile"
        mkdir -p "$mnt/etc/salt"
        cat > "$mnt/etc/salt/grains" <<GRAINS
host: ${profile}
GRAINS
    fi

    # Force networking and SSH for VM
    log_info "Configuring network and SSH for VM..."
    mkdir -p "$mnt/etc/ssh/sshd_config.d" \
        "$mnt/etc/systemd/system" \
        "$mnt/etc/modules-load.d" \
        "$mnt/etc/systemd/system/multi-user.target.wants"
    cat > "$mnt/etc/ssh/sshd_config.d/99-kvm-test.conf" <<'SSHD'
PermitRootLogin yes
PasswordAuthentication yes
SSHD
    # Force-load virtio_net (autodetect hook in mkinitcpio strips it)
    echo "virtio_net" > "$mnt/etc/modules-load.d/virtio-net.conf"
    # Systemd unit to ensure networking works (fallback if NM fails)
    cat > "$mnt/etc/systemd/system/kvm-network.service" <<'UNIT'
[Unit]
Description=KVM network and SSH
Before=sshd.service
DefaultDependencies=no

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/bash -c '
    echo "kvm-network: starting" > /dev/console
    lsmod > /tmp/lsmod-before.txt 2>&1
    modprobe virtio_net 2>/tmp/modprobe-err.txt || true
    modprobe e1000 2>>/tmp/modprobe-err.txt || true
    lsmod > /tmp/lsmod-after.txt 2>&1
    ip link > /tmp/ip-link.txt 2>&1
    for i in $(seq 1 15); do
        for iface in /sys/class/net/e*; do
            [ -d "$iface" ] || continue
            name=$(basename "$iface")
            [ "$name" = "lo" ] && continue
            ip link set "$name" up 2>/dev/null || true
            ip addr flush dev "$name" 2>/dev/null || true
            ip addr add 10.0.2.15/24 dev "$name" 2>/dev/null || true
            ip route add default via 10.0.2.2 2>/dev/null || true
            echo "kvm-network: $name up 10.0.2.15" > /dev/console
            exit 0
        done
        sleep 2
    done
    echo "kvm-network: FAILED - no interface" > /dev/console
    ip link > /tmp/ip-link-fail.txt 2>&1
'

[Install]
WantedBy=multi-user.target
UNIT
    ln -sf /etc/systemd/system/kvm-network.service \
        "$mnt/etc/systemd/system/multi-user.target.wants/kvm-network.service"
    local pw_hash
    pw_hash=$(openssl passwd -6 "root" 2>/dev/null \
        || python3 -c 'import crypt; print(crypt.crypt("root", crypt.mksalt(crypt.METHOD_SHA512)))')
    sed -i "s|^root:[^:]*:|root:${pw_hash}:|" "$mnt/etc/shadow"

    # Mount ESP
    mount "$efipart" "$mnt/boot"
    rsync "${RSYNC_ARGS[@]}" "$rootfs/boot/" "$mnt/boot/"

    # Generate fstab
    log_info "Generating fstab..."
    local efi_uuid root_uuid
    efi_uuid=$(blkid -s UUID -o value "$efipart")
    root_uuid=$(blkid -s UUID -o value "$rootpart")

    cat > "$mnt/etc/fstab" <<FSTAB
# CachyOS VM fstab (generated by test-kvm-deploy.sh)
UUID=${root_uuid}  /              btrfs  subvol=@,compress=zstd:1,noatime          0  0
UUID=${root_uuid}  /home          btrfs  subvol=@home,compress=zstd:1,noatime      0  0
UUID=${root_uuid}  /var/cache     btrfs  subvol=@cache,compress=zstd:1,noatime     0  0
UUID=${root_uuid}  /var/log       btrfs  subvol=@log,compress=zstd:1,noatime       0  0
UUID=${efi_uuid}   /boot          vfat   umask=0077                                0  1
FSTAB

    # Update Limine config
    log_info "Writing bootloader config..."
    cat > "$mnt/boot/limine.conf" <<LIMINE
timeout: 5
default_entry: 1
interface_branding: CachyOS VM (kvm-deploy)

/CachyOS
    protocol: linux
    kernel_path: boot():/vmlinuz-linux-cachyos-lts
    kernel_cmdline: root=UUID=${root_uuid} rootflags=subvol=@ rw console=ttyS0,115200 console=tty0
    module_path: boot():/initramfs-linux-cachyos-lts.img

/CachyOS (fallback)
    protocol: linux
    kernel_path: boot():/vmlinuz-linux-cachyos-lts
    kernel_cmdline: root=UUID=${root_uuid} rootflags=subvol=@ rw console=ttyS0,115200 console=tty0
    module_path: boot():/initramfs-linux-cachyos-lts-fallback.img
LIMINE

    # Install Limine EFI
    mkdir -p "$mnt/boot/EFI/BOOT"
    if [[ -f "$mnt/usr/share/limine/BOOTX64.EFI" ]]; then
        cp "$mnt/usr/share/limine/BOOTX64.EFI" "$mnt/boot/EFI/BOOT/BOOTX64.EFI"
        log_info "Limine EFI installed"
    else
        echo "error: Limine EFI binary not found at $mnt/usr/share/limine/BOOTX64.EFI" >&2
        echo "  ensure limine is installed in the rootfs" >&2
        exit 2
    fi

    # Unmount
    log_info "Unmounting..."
    umount -R "$mnt" 2>/dev/null || true
    qemu-nbd --disconnect "$nbd_dev"

    # Copy OVMF vars
    cp "$OVMF_VARS_TEMPLATE" "$ovmf_vars"

    echo "DISK=$disk" > "${vm_dir}/.vm-info"
    echo "OVMF_VARS=$ovmf_vars" >> "${vm_dir}/.vm-info"
    echo "NBD_DEV=$nbd_dev" >> "${vm_dir}/.vm-info"
    log_info "VM image ready: $disk"
}

# ---------------------------------------------------------------------------
# SSH helpers
# ---------------------------------------------------------------------------
wait_for_ssh() {
    local port="$1"
    local timeout_sec="${2:-300}"
    local interval=1
    local elapsed=0
    local max_interval=30

    log_phase "Waiting for SSH on port $port..."
    while (( elapsed < timeout_sec )); do
        if _ssh_with_pass "$port" root "echo ok" >/dev/null 2>&1; then
            echo "    SSH ready after ${elapsed}s"
            return 0
        fi
        sleep "$interval"
        ((elapsed += interval))
        interval=$(( interval * 2 < max_interval ? interval * 2 : max_interval ))
    done
    echo "error: SSH timeout after ${timeout_sec}s" >&2
    return 1
}

ssh_exec() {
    local port="$1"
    shift
    _ssh_with_pass "$port" root "$@"
}

ssh_exec_quiet() {
    local port="$1"
    shift
    _ssh_with_pass "$port" root "$@" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Profile resolution
# ---------------------------------------------------------------------------
resolve_profile() {
    local profile="$1"
    local salt_repo="$2"

    if [[ "$profile" == "all" ]]; then
        python3 -c "
import yaml
with open('${salt_repo}/states/data/feature_matrix.yaml') as f:
    profiles = yaml.safe_load(f)
for p in profiles:
    print(p['name'])
" 2>/dev/null || {
            echo "error: failed to read feature_matrix.yaml" >&2
            return 1
        }
        return 0
    fi

    echo "$profile"
}

# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Salt execution
# ---------------------------------------------------------------------------
run_salt_apply() {
    local ssh_port="$1"
    local timeout_sec="${2:-900}"

    log_phase "Running salt-apply.sh inside VM..."

    local salt_output
    salt_output=$(ssh_exec "$ssh_port" "
        cd /srv/salt
        export SALT_CONFIG_DIR=/srv/salt
        bash scripts/salt-apply.sh 2>&1
    ")
    local rc=$?

    echo "$salt_output"

    # Parse summary — look for "Summary" line or count succeeded/failed
    local succeeded failed unchanged
    succeeded=$(echo "$salt_output" | grep -oP 'Succeeded:\s*\K\d+' | tail -1)
    failed=$(echo "$salt_output" | grep -oP 'Failed:\s*\K\d+' | tail -1)
    unchanged=$(echo "$salt_output" | grep -oP 'Unchanged:\s*\K\d+' | tail -1)

    succeeded=${succeeded:-0}
    failed=${failed:-0}
    unchanged=${unchanged:-0}

    echo ""
    echo "    Salt result: ${succeeded} succeeded, ${failed} failed, ${unchanged} unchanged"

    return $rc
}

# ---------------------------------------------------------------------------
# Health check
# ---------------------------------------------------------------------------
run_health_check() {
    local ssh_port="$1"

    log_phase "Running health-check.sh inside VM..."

    local health_output
    health_output=$(ssh_exec_quiet "$ssh_port" "
        cd /srv/salt
        if [[ -x scripts/health-check.sh ]]; then
            bash scripts/health-check.sh 2>&1
        else
            echo 'SKIP: health-check.sh not found'
        fi
    ")
    local rc=$?

    echo "$health_output"

    # Parse health status
    local healthy failed
    healthy=$(echo "$health_output" | grep -c "HEALTHY\|OK\|active\|running" 2>/dev/null || echo 0)
    failed=$(echo "$health_output" | grep -c "FAILED\|ERROR\|inactive\|failed" 2>/dev/null || echo 0)

    echo "    Health: ${healthy:-0} healthy, ${failed:-0} failed"

    if (( ${failed:-0} > 0 )); then
        return 1
    fi
    return 0
}

# ---------------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------------
kill_port_owner() {
    local port="$1"
    local pid
    pid=$(ss -tlnp "sport = :${port}" 2>/dev/null | grep -oP 'pid=\K\d+' | head -1)
    if [[ -n "$pid" ]]; then
        log_info "Port ${port} in use by pid ${pid}, killing..."
        kill "$pid" 2>/dev/null || true
        sleep 1
        kill -9 "$pid" 2>/dev/null || true
    fi
}

cleanup_vm() {
    local vm_dir="$1"
    local qemu_pid="$2"

    log_phase "Cleaning up..."

    # Kill QEMU if still running
    if [[ -n "$qemu_pid" ]] && kill -0 "$qemu_pid" 2>/dev/null; then
        log_info "Stopping QEMU (pid $qemu_pid)..."
        kill "$qemu_pid" 2>/dev/null || true
        sleep 1
        kill -9 "$qemu_pid" 2>/dev/null || true
    fi

    # Disconnect any stale NBD
    local nbd_dev
    if [[ -f "${vm_dir}/.vm-info" ]]; then
        nbd_dev=$(grep NBD_DEV "${vm_dir}/.vm-info" 2>/dev/null | cut -d= -f2)
        if [[ -n "$nbd_dev" ]]; then
            qemu-nbd --disconnect "$nbd_dev" 2>/dev/null || true
        fi
    fi

    # Remove temp files
    if [[ -d "$vm_dir" ]]; then
        rm -rf "$vm_dir"
        log_info "Removed $vm_dir"
    fi
}

# ---------------------------------------------------------------------------
# JSON report generation
# ---------------------------------------------------------------------------
generate_report_json() {
    local output_file="$1"
    shift

    python3 -c "
import json, sys

profiles = []
i = 1  # skip '-c'
while i + 4 < len(sys.argv):
    profile = sys.argv[i]
    status = sys.argv[i+1]
    salt_ok = int(sys.argv[i+2] or 0)
    salt_fail = int(sys.argv[i+3] or 0)
    health = sys.argv[i+4]
    profiles.append({
        'profile': profile,
        'status': status,
        'salt_succeeded': salt_ok,
        'salt_failed': salt_fail,
        'health': health
    })
    i += 5

total = len(profiles)
passed = sum(1 for p in profiles if p['status'] == 'PASS')
report = {
    'total_profiles': total,
    'passed': passed,
    'failed': total - passed,
    'profiles': profiles
}

print(json.dumps(report, indent=2))
" "$@"
}
