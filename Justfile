# Salt configuration management
#
# Usage:
#   just          # auto mode — apply minimal Salt state via git diff
#   just apply    # same
#   just apply system_description
#   just apply hardware
#   just test     # dry-run system_description
#   just test kernel_modules

# Apply a state (default: auto — minimal-rollout via git diff)
apply STATE="auto":
    #!/usr/bin/env bash
    set -o pipefail
    scripts/salt-apply.sh {{STATE}}
    rc=$?
    if [[ $rc -ne 0 ]]; then
        log=$(ls -t logs/*.log 2>/dev/null | head -1)
        echo ""
        echo "▸▸▸ apply failed (exit $rc)"
        echo "▸ Log: ${log:-none}"
        echo "▸ Failed states: grep 'Result: False' ${log:-logs/*.log}"
        echo "▸ Missing deps:  grep 'Requisite.*not found' ${log:-logs/*.log}"
        echo "▸ Validate:      just validate"
        echo "▸ Contracts:     python3 scripts/salt_contracts.py"
        echo "▸ Force:         just force"
    fi
    exit $rc

# Apply a state skipping contract validation (--force)
apply-force STATE="auto":
    scripts/salt-apply.sh {{STATE}} --force

# Short alias for apply-force
force STATE="auto":
    just apply-force {{STATE}}

apply-plan *FILES:
    ./scripts/salt-apply.sh auto --plan {{FILES}}

apply-auto:
    ./scripts/salt-apply.sh auto

# Apply dotfiles only (chezmoi, no Salt)
dotfiles:
    #!/usr/bin/env bash
    set -euo pipefail
    gpg-connect-agent updatestartuptty /bye &>/dev/null || true
    install -Dm644 dotfiles/dot_config/chezmoi/chezmoi.toml \
        "${HOME}/.config/chezmoi/chezmoi.toml" 2>/dev/null || true
    chezmoi apply --force --source dotfiles

apply-user-services:
    scripts/salt-apply.sh user_services

apply-installers:
    scripts/salt-apply.sh installers

# Apply a state group (core, network, desktop, packages, services, ai)
group GROUP:
    scripts/salt-apply.sh group/{{GROUP}}

# Show which states would be applied (without executing)
show STATE="system_description":
    python3 scripts/salt_show.py {{STATE}}

# Capture current system packages into states/data/packages.yaml
pkg-snapshot *ARGS:
    ./scripts/pkg-snapshot.zsh {{ARGS}}

# Compare declared packages against actual system state
pkg-drift *ARGS:
    ./scripts/pkg-drift.zsh {{ARGS}}

# List available recipes
help:
    @just --list

# Dry-run a state — no changes applied
test STATE="system_description":
    scripts/salt-apply.sh {{STATE}} --test

# Run unit tests (data validation, host config, merge)
test-unit *ARGS:
    .venv/bin/pytest tests/ -v {{ARGS}}

# Run CachyOS VM smoke test inside Podman
vm-smoke ROOTFS="/mnt/one/cachyos-root":
    sudo scripts/vm-smoke.sh {{ROOTFS}}

# Start the salt daemon (keeps running, speeds up subsequent applies)
daemon:
    sudo scripts/salt-daemon.py \
        --config-dir .salt_runtime \
        --log-level warning

# Regenerate Claude Code knowledge base indexes
index:
    python scripts/index-qml.py
    python scripts/index-salt.py

# Show provenance for a state name
provenance STATE:
    .venv/bin/python3 scripts/salt_provenance.py --state "{{STATE}}"

# Show provenance for a state ID
provenance-id STATE_ID:
    .venv/bin/python3 scripts/salt_provenance.py --state-id "{{STATE_ID}}"

# Lint Salt states and Python scripts
lint:
    bash scripts/lint-all.sh

# Format Python scripts
fmt:
    .venv/bin/ruff format .

# List all tools with install status
tools:
    .venv/bin/python3 scripts/update-tools.py

# Check for available GitHub release updates
check-updates:
    .venv/bin/python3 scripts/update-tools.py --check

# Update tools (specify tool names or --all)
update-tools *ARGS:
    .venv/bin/python3 scripts/update-tools.py --update {{ARGS}}

# Verify a state would make no changes (idempotency check)
idempotency STATE="system_description":
    #!/usr/bin/env bash
    set -uo pipefail
    echo "--- Idempotency check: {{STATE}} ---"
    scripts/salt-apply.sh {{STATE}} --test
    log=$(ls -t logs/{{STATE}}-*.log 2>/dev/null | head -1)
    if [ -z "$log" ]; then
        echo "ERROR: no log file found"
        exit 1
    fi
    # Salt summary lines look like: "Succeeded: N (changed=M)" or "Succeeded: N (unchanged=M)"
    # Only check the summary, not echo statements inside rendered templates.
    summary=$(grep -oP 'Succeeded: \d+ \(changed=\K\d+' "$log" || echo "0")
    if [ "$summary" -gt 0 ]; then
        echo ""
        echo "FAIL: non-idempotent states detected ($summary changed states in $log)"
        grep 'Succeeded:' "$log"
        exit 1
    fi
    echo "PASS: all states idempotent"

# Verify sysctl-custom.conf values are applied on live system
lint-sysctl:
    .venv/bin/python3 scripts/lint-sysctl.py

# Check all state files render without errors (no execution, parallel)
validate JOBS="":
    scripts/salt-validate.sh {{JOBS}}

# Run data contract checks (cross-file consistency validation)
contracts:
    python3 scripts/salt_contracts.py

# Run full data validation pipeline (contracts + schema tests + cross-refs)
check:
    python3 scripts/salt_contracts.py --verbose
    python3 -m pytest tests/test_data_crossrefs.py tests/test_yaml_schemas.py tests/test_host_model.py -q

# Run data contract checks with verbose summary
contracts-verbose:
    python3 scripts/salt_contracts.py --verbose

# Data health overview (files, features, packages, services, contract status)
health-data:
    python3 scripts/salt_contracts.py --summary

# Data statistics (file sizes, last modified, consumer counts)
stats:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "=== Data files ==="
    for f in states/data/*.yaml; do
        size=$(stat -c%s "$f" 2>/dev/null || stat -f%z "$f" 2>/dev/null)
        printf "  %-35s %6d bytes\n" "$(basename "$f")" "$size"
    done
    echo ""
    echo "=== SLS files ==="
    sls_count=$(find states -name '*.sls' | wc -l)
    jinja_count=$(find states -name '*.jinja' -not -name '_macros_*' | wc -l)
    macro_count=$(find states -name '_macros_*.jinja' | wc -l)
    echo "  .sls files:        $sls_count"
    echo "  macro .jinja files: $macro_count"
    echo "  other .jinja files: $jinja_count"
    echo ""
    echo "=== Tests ==="
    test_count=$(find tests -name 'test_*.py' | wc -l)
    echo "  test files: $test_count"
    echo ""
    python3 scripts/salt_contracts.py --summary

# Run Salt with data audit (track which data files are consumed)
audit TARGET="system_description":
    scripts/salt-apply.sh --audit {{TARGET}}

# Show unused data files from the latest audit log
audit-diff LOG="":
    #!/usr/bin/env bash
    if [ -z "{{LOG}}" ]; then
        LOG=$(ls -t logs/audit-*.yaml 2>/dev/null | head -1)
    fi
    if [ -z "$LOG" ]; then
        echo "No audit log found. Run: just audit"
        exit 1
    fi
    python3 scripts/salt_audit.py --diff "$LOG"

# Print data→state dependency graph (JSON)
graph:
    python3 scripts/salt_impact.py --graph

# Show Salt apply impact plan for uncommitted changes
impact:
    #!/usr/bin/env bash
    set -euo pipefail
    changed=$(git diff --name-only HEAD 2>/dev/null || true)
    if [ -z "$changed" ]; then
        changed=$(git diff --name-only --cached 2>/dev/null || true)
    fi
    if [ -z "$changed" ]; then
        echo "No uncommitted changes"
        exit 0
    fi
    python3 scripts/salt_impact.py --files ${changed} --json > /tmp/_impact.json
    python3 scripts/salt_impact.py --files ${changed} | tail -n +2

# Check one explicit state file render without a full repository pass
validate-one STATE:
    scripts/salt-validate.sh -- {{STATE}}

# Check multiple explicit state file renders without a full repository pass
validate-some *STATES:
    scripts/salt-validate.sh -- {{STATES}}

drift:
    python3 scripts/drift_state.py fast --project-dir "${PWD}"

drift-full:
    python3 scripts/drift_state.py full --project-dir "${PWD}"

drift-status:
    python3 scripts/drift_state.py status --project-dir "${PWD}"

# Drift report (JSON format)
drift-report:
    python3 scripts/drift_state.py status --project-dir "${PWD}" --json

# Suppress salt-monitor alerts during maintenance
drift-maintenance-on:
    python3 scripts/drift_state.py --maintenance on --cache-dir "${HOME}/.cache/salt-monitor"

# Re-enable salt-monitor alerts after maintenance
drift-maintenance-off:
    python3 scripts/drift_state.py --maintenance off --cache-dir "${HOME}/.cache/salt-monitor"

# Refresh expected-snapshot.json baseline
drift-refresh TARGET="system_description":
    python3 scripts/drift_state.py refresh-expected --project-dir "${PWD}" --salt-target "{{TARGET}}"

# Check if salt-daemon is running and responsive
daemon-health:
    #!/usr/bin/env bash
    sock="${SALT_DAEMON_SOCK:-/run/salt-daemon.sock}"
    if [ ! -S "$sock" ]; then
        echo "OFFLINE (no socket at $sock)"
        exit 1
    fi
    if python3 -c "
    import socket, sys
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.settimeout(2)
    s.connect('$sock')
    s.close()
    " 2>/dev/null; then
        echo "HEALTHY (listening on $sock)"
    else
        echo "UNHEALTHY (socket exists but not responding)"
        exit 1
    fi

# Remove generated runtime files (venv and salt runtime config)
clean:
    rm -rf __pycache__ .salt_runtime .venv

# Render all states for every feature-matrix scenario (template smoke test)
render-matrix:
    python3 scripts/render-matrix.py

# Show matching Salt debug bundles as JSON
debug-bundle *ARGS:
    python3 scripts/salt_debug_report.py {{ARGS}}

# Profile Salt state durations from the latest log (or provided LOG)
profile LOG="":
    #!/usr/bin/env bash
    set -euo pipefail
    log="{{LOG}}"
    if [ -z "$log" ]; then
        log=$(ls -t logs/*.log 2>/dev/null | head -1)
    fi
    if [ -z "$log" ]; then
        echo "No logs found" >&2
        exit 1
    fi
    python3 scripts/state-profiler.py "$log"

# Prune log files older than N days (default 14)
logs-prune DAYS="14" DRY_RUN="":
    if [ "{{DRY_RUN}}" = "1" ]; then \
        python3 scripts/cleanup-logs.py --days {{DAYS}} --dry-run; \
    else \
        python3 scripts/cleanup-logs.py --days {{DAYS}}; \
    fi

# Generate Salt state dependency graph
dep-graph *ARGS:
    #!/usr/bin/env bash
    set -euo pipefail
    args=({{ARGS}})
    if [ ${#args[@]} -eq 0 ]; then
        python3 scripts/dep-graph.py --format svg --output logs/dep-graph.svg
        echo "Written to logs/dep-graph.svg"
        handlr open logs/dep-graph.svg 2>/dev/null || echo "Open logs/dep-graph.svg to view"
    else
        python3 scripts/dep-graph.py "${args[@]}"
    fi

# Run container-based smoke test (Podman)
smoke-test *ARGS:
    tests/smoke-test.sh {{ARGS}}

# Profile state durations with optional trend analysis
profile-trend:
    python3 scripts/state-profiler.py --trend

# Compare two state apply logs for regressions
profile-compare LOG1 LOG2:
    python3 scripts/state-profiler.py --compare {{LOG1}} {{LOG2}}

# Enable hybrid VPN (Xray + sing-box TUN)
vpn-enable:
    scripts/enable-vpn-hybrid.sh --enable-flags --apply

# Start hybrid VPN manually (without Salt)
vpn-start:
    scripts/start-hybrid-vpn.sh

# Check VPN status
vpn-status:
    scripts/check-vpn-status.sh

# Stop hybrid VPN
vpn-stop:
    #!/usr/bin/env bash
    set -euo pipefail
    sudo systemctl stop xray 2>/dev/null || true
    sudo systemctl stop sing-box-tun-hybrid 2>/dev/null || true
    pkill -f "xray run" 2>/dev/null || true
    pkill -f "sing-box run" 2>/dev/null || true
    echo "VPN stopped"

# Check health of all Salt-managed services
health *ARGS:
    ~/.local/bin/salt-alert --health {{ARGS}}

# Check Loki readiness (full check with timeout)
check-loki:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Checking Loki readiness..."
    for i in $(seq 1 120); do
        if curl -sf --max-time 5 http://127.0.0.1:3100/ready >/dev/null 2>&1; then
            echo "Loki is ready"
            exit 0
        fi
        sleep 1
    done
    echo "Loki failed to become ready within 120s" >&2
    exit 1

# --- KVM Deployment Testing ---
kvm-test-minimal:
    just kvm-cleanup
    sudo scripts/test-kvm-deploy.sh --profile matrix-minimal

kvm-test-containerized:
    just kvm-cleanup
    sudo scripts/test-kvm-deploy.sh --profile matrix-containerized

kvm-deploy PROFILE="matrix-minimal":
    just kvm-cleanup
    sudo scripts/test-kvm-deploy.sh --profile {{PROFILE}}

kvm-deploy-all:
    sudo scripts/test-kvm-deploy.sh --profile all

kvm-deploy-debug PROFILE="matrix-minimal":
    sudo scripts/test-kvm-deploy.sh --profile {{PROFILE}} --keep-vm

kvm-cleanup:
    sudo umount -l /mnt 2>/dev/null || true
    sudo pkill -9 -x qemu-system-x86_64 2>/dev/null || true
    sudo pkill -9 -x qemu-nbd 2>/dev/null || true
    sudo timeout 5 qemu-nbd --disconnect /dev/nbd0 2>/dev/null || true
    sudo timeout 5 qemu-nbd --disconnect /dev/nbd1 2>/dev/null || true
    sudo rm -rf /tmp/kvm-deploy-* /tmp/manual-* 2>/dev/null || true
    echo "cleaned"

# Full pipeline: bootstrap CachyOS rootfs, then test deployment
kvm-bootstrap TARGET="/mnt/one/cachyos-root":
    sudo scripts/bootstrap-cachyos.sh {{TARGET}}
    echo "Rootfs bootstrapped. Fixing initramfs for VM networking..."
    sudo sed -i 's/^MODULES=()/MODULES=(virtio_net e1000)/' {{TARGET}}/etc/mkinitcpio.conf
    sudo sed -i 's/autodetect //' {{TARGET}}/etc/mkinitcpio.conf
    sudo systemd-nspawn -D {{TARGET}} mkinitcpio -P
    sudo systemd-nspawn -D {{TARGET}} depmod -a $(ls {{TARGET}}/lib/modules/ | head -1)
    sudo cp scripts/kvm-network-rc-local.sh {{TARGET}}/etc/rc.local
    sudo chmod +x {{TARGET}}/etc/rc.local
    echo "Rootfs ready for VM testing."

# Full CI pipeline: bootstrap + deploy + test
kvm-ci:
    just kvm-bootstrap
    just kvm-test-minimal
