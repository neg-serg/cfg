#!/usr/bin/env zsh
# test-kvm-deploy.sh — KVM/QEMU Salt deployment test runner
#
# Boots a CachyOS rootfs in a QEMU/KVM VM, applies Salt states,
# runs health checks, and reports pass/fail results.
#
# Usage:
#   sudo ./scripts/test-kvm-deploy.sh --profile matrix-minimal
#   sudo ./scripts/test-kvm-deploy.sh --profile all
#   sudo ./scripts/test-kvm-deploy.sh --profile matrix-minimal --keep-vm

set -euo pipefail

SCRIPT_DIR="${0:A:h}"
source "${SCRIPT_DIR}/test-kvm-deploy-lib.sh"

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
ROOTFS="${ROOTFS:-/mnt/one/cachyos-root}"
PROFILE="matrix-minimal"
SALT_REPO="${PWD}"
TIMEOUT_BOOT=300
TIMEOUT_SALT=900
SSH_PORT=2222
NO_HEALTH_CHECK=false
KEEP_VM=false
FAIL_FAST=false
OUTPUT_DIR="logs"
JSON_OUTPUT=false

# ---------------------------------------------------------------------------
# Arguments
# ---------------------------------------------------------------------------
usage() {
    cat <<'EOF'
Usage: test-kvm-deploy.sh [OPTIONS]

Options:
  --rootfs PATH       Path to CachyOS rootfs (default: /mnt/one/cachyos-root)
  --profile NAME      Profile from feature_matrix.yaml, "all", or custom YAML
  --salt-repo PATH    Path to Salt repository (default: current dir)
  --timeout-boot SEC  Max seconds to wait for VM SSH (default: 300)
  --timeout-salt SEC  Max seconds to wait for salt-apply (default: 900)
  --ssh-port PORT     Host port forwarded to VM SSH (default: 2222)
  --no-health-check   Skip health-check.sh after Salt apply
  --keep-vm           Do not destroy VM after test (for debugging)
  --fail-fast         Stop after first profile failure (with --profile all)
  --output-dir PATH   Log output directory (default: logs)
  --json              Output JSON report file
  --help              Show this help
EOF
    exit 0
}

while (( $# > 0 )); do
    case "$1" in
        --rootfs)          ROOTFS="$2"; shift 2 ;;
        --profile)         PROFILE="$2"; shift 2 ;;
        --salt-repo)       SALT_REPO="$2"; shift 2 ;;
        --timeout-boot)    TIMEOUT_BOOT="$2"; shift 2 ;;
        --timeout-salt)    TIMEOUT_SALT="$2"; shift 2 ;;
        --ssh-port)        SSH_PORT="$2"; shift 2 ;;
        --no-health-check) NO_HEALTH_CHECK=true; shift ;;
        --keep-vm)         KEEP_VM=true; shift ;;
        --fail-fast)       FAIL_FAST=true; shift ;;
        --output-dir)      OUTPUT_DIR="$2"; shift 2 ;;
        --json)            JSON_OUTPUT=true; shift ;;
        --help)            usage ;;
        *) echo "error: unknown option $1" >&2; exit 3 ;;
    esac
done

ROOTFS="${KVM_DEPLOY_ROOTFS:-$ROOTFS}"
PROFILE="${KVM_DEPLOY_PROFILE:-$PROFILE}"
SSH_PORT="${KVM_DEPLOY_SSH_PORT:-$SSH_PORT}"

# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------
check_root
check_prereqs
check_rootfs "$ROOTFS"
check_kvm

KVM_ACCEL="kvm"
if [[ -f "/tmp/kvm-deploy-no-kvm" ]]; then
    KVM_ACCEL="tcg"
fi

# Resolve profile list
PROFILES=()
if [[ "$PROFILE" == "all" ]]; then
    while IFS= read -r p; do
        [[ -n "$p" ]] && PROFILES+=("$p")
    done < <(resolve_profile "$PROFILE" "$SALT_REPO")
    echo "==> Testing all ${#PROFILES[@]} profiles"
else
    PROFILES=("$PROFILE")
fi

# Init logging (side-effect: sets LOG_FILE)
log_init "$OUTPUT_DIR"

# ---------------------------------------------------------------------------
# Run tests per profile
# ---------------------------------------------------------------------------
declare -A RESULTS
GLOBAL_PASS=true

for prof in "${PROFILES[@]}"; do
    echo ""
    echo "========================================"
    echo "  Profile: $prof"
    echo "========================================"

    VM_DIR=$(mktemp -d "/tmp/kvm-deploy-XXXXX")
    QEMU_PID=""

    trap_cleanup() {
        if [[ "$KEEP_VM" == false ]]; then
            cleanup_vm "$VM_DIR" "$QEMU_PID"
        else
            echo "==> Keeping VM alive"
            echo "    SSH: ssh -p ${SSH_PORT} root@localhost"
        fi
    }
    trap trap_cleanup EXIT INT TERM

    # 1. Build VM image (writes grains for this profile inside)
    if ! build_vm_image "$ROOTFS" "$VM_DIR" "$SALT_REPO" "$prof"; then
        RESULTS["$prof"]="INFRA_ERROR"
        if $FAIL_FAST; then exit 2; fi
        trap - EXIT INT TERM
        continue
    fi

    # 2. Boot VM
    log_phase "Booting VM (accel=$KVM_ACCEL)..."

    # Kill anything using our SSH port
    kill_port_owner "$SSH_PORT"

    # Source vm-info via dot to avoid subshell
    set -a
    . "${VM_DIR}/.vm-info"
    set +a

    qemu-system-x86_64 \
        -machine "q35,accel=${KVM_ACCEL}" \
        -cpu host \
        -smp 4 \
        -m 4G \
        -drive "if=pflash,format=raw,readonly=on,file=${OVMF_CODE}" \
        -drive "if=pflash,format=raw,file=${OVMF_VARS}" \
        -drive "file=${DISK},format=qcow2,if=virtio" \
        -nic "user,model=virtio-net-pci,hostfwd=tcp::${SSH_PORT}-:22" \
        -nographic \
        > "${VM_DIR}/qemu.console" 2>&1 &

    QEMU_PID=$!
    echo "$QEMU_PID" > "${VM_DIR}/qemu.pid"

    sleep 3
    if ! kill -0 "$QEMU_PID" 2>/dev/null; then
        log_error "QEMU died immediately after start"
        cat "${VM_DIR}/qemu.stderr" 2>/dev/null
        cat "${VM_DIR}/qemu.stdout" 2>/dev/null
        RESULTS["$prof"]="INFRA_ERROR"
        if $FAIL_FAST; then exit 2; fi
        trap_cleanup; trap - EXIT INT TERM; continue
    fi
    log_info "QEMU PID: $QEMU_PID"

    # 3. Wait for SSH
    if ! wait_for_ssh "$SSH_PORT" "$TIMEOUT_BOOT"; then
        log_error "SSH timeout — VM may have failed to boot"
        RESULTS["$prof"]="TIMEOUT_BOOT"
        if $FAIL_FAST; then exit 2; fi
        trap_cleanup; trap - EXIT INT TERM; continue
    fi

    # 4. Ensure Salt is installed in the VM
    log_phase "Ensuring Salt is installed..."
    ssh_exec_quiet "$SSH_PORT" "
        command -v salt-call >/dev/null 2>&1 || {
            pacman -Sy --noconfirm --needed salt 2>&1 || true
        }
    "
    log_info "Salt ready"

    # 5. Run salt-apply.sh
    salt_rc=0
    if ! run_salt_apply "$SSH_PORT" "$TIMEOUT_SALT"; then
        salt_rc=1
    fi

    # 6. Run health-check.sh (if not skipped)
    health_rc=0
    if [[ "$NO_HEALTH_CHECK" == false ]]; then
        if ! run_health_check "$SSH_PORT"; then
            health_rc=1
        fi
    else
        log_info "Health check skipped (--no-health-check)"
    fi

    # 7. Determine result
    if (( salt_rc != 0 )); then
        RESULTS["$prof"]="FAIL_SALT"
        GLOBAL_PASS=false
        echo "==> $prof: FAIL (Salt errors)"
    elif (( health_rc != 0 )); then
        RESULTS["$prof"]="FAIL_HEALTH"
        GLOBAL_PASS=false
        echo "==> $prof: FAIL (unhealthy services)"
    else
        RESULTS["$prof"]="PASS"
        echo "==> $prof: PASS"
    fi

    # 8. Cleanup
    trap_cleanup
    trap - EXIT INT TERM

    if $FAIL_FAST && [[ "${RESULTS[$prof]}" != "PASS" ]]; then
        echo "==> Stopping: --fail-fast"
        exit 1
    fi
done

# ---------------------------------------------------------------------------
# Final report
# ---------------------------------------------------------------------------
echo ""
echo "========================================"
echo "  Results Summary"
echo "========================================"

PASSED=0
FAILED=0
for prof in "${PROFILES[@]}"; do
    pstatus="${RESULTS[$prof]:-NOT_RUN}"
    case "$pstatus" in
        PASS) ((PASSED++)); mark="PASS" ;;
        *)    ((FAILED++)); mark="FAIL" ;;
    esac
    echo "  ${mark}: $prof (${pstatus})"
done

echo "----------------------------------------"
echo "  Total: ${#PROFILES[@]} | Passed: $PASSED | Failed: $FAILED"

# JSON report
if $JSON_OUTPUT; then
    JSON_ARGS=()
    for prof in "${PROFILES[@]}"; do
        JSON_ARGS+=("$prof" "${RESULTS[$prof]:-NOT_RUN}" "0" "0" "N/A")
    done
    REPORT_FILE="${OUTPUT_DIR}/test-kvm-deploy-$(date +%Y%m%d-%H%M%S).json"
    generate_report_json "$REPORT_FILE" "${JSON_ARGS[@]}" > "$REPORT_FILE"
    echo "  JSON: $REPORT_FILE"
fi

if $GLOBAL_PASS; then
    exit 0
else
    exit 1
fi
