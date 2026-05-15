#!/usr/bin/env bash
# Apply critical Salt states at boot time.
# Usage: salt-boot-apply.sh <project_dir>
# Exit 0: all states applied successfully
# Exit 1: one or more states failed (logged to journal + log file)
# NEVER blocks boot — systemd unit uses WantedBy= not RequiredBy=.
set -euo pipefail

PROJECT_DIR="${1:-/home/neg/src/cfg}"
LOG_FILE="/var/log/salt-boot-apply.log"
MARKER="/var/lib/salt-boot/last-success"
SALT_CALL="${PROJECT_DIR}/.venv/bin/salt-call"

mkdir -p "$(dirname "$LOG_FILE")" "$(dirname "$MARKER")"

if [[ ! -x "$SALT_CALL" ]]; then
    echo "salt-boot-apply: $SALT_CALL not found or not executable — skipping" >&2
    exit 0
fi

echo "=== Salt boot apply started at $(date -u '+%Y-%m-%dT%H:%M:%SZ') ===" | tee -a "$LOG_FILE"

# Sync custom execution/states modules from _modules/ and _states/.
# The salt-daemon handles this on its own startup, but salt-boot-apply may
# run before the daemon is ready on first boot.  This no-ops if current.
"$SALT_CALL" --local --config-dir="${PROJECT_DIR}/.salt_runtime" saltutil.sync_all >/dev/null 2>&1 || true

# Apply core group: users, mounts, kernel modules, sysctl, hardware, etc.
# No --failhard: apply ALL critical states even if some fail.
# Salt is idempotent — a failed state leaves the current (working) state intact.
if "$SALT_CALL" \
    --local \
    --config-dir="${PROJECT_DIR}/.salt_runtime" \
    --log-level=warning \
    --log-file="$LOG_FILE" \
    --log-file-level=debug \
    --retcode-passthrough \
    --state-output=mixed \
    state.sls group/core; then

    date -u '+%Y-%m-%dT%H:%M:%SZ' > "$MARKER"
    echo "=== Salt boot apply completed successfully at $(date -u '+%Y-%m-%dT%H:%M:%SZ') ===" | tee -a "$LOG_FILE"
    exit 0
else
    RC=$?
    echo "=== Salt boot apply FAILED (exit $RC) at $(date -u '+%Y-%m-%dT%H:%M:%SZ') ===" | tee -a "$LOG_FILE"

    # Count failed states for journal visibility
    if [[ -f "$LOG_FILE" ]]; then
        FAILED=$(grep -c 'Result: False' "$LOG_FILE" 2>/dev/null || echo "?")
        echo "salt-boot-apply: $FAILED states failed — check $LOG_FILE" >&2
    fi

    # Write failure timestamp so drift monitor can show "last boot apply FAILED"
    echo "FAILED $(date -u '+%Y-%m-%dT%H:%M:%SZ')" > "${MARKER}.failed"

    # Non-zero exit signals systemd (for monitoring), but WantedBy= ensures
    # boot continues. No RequiredBy=, no Before=, no After= ordering constraints
    # that could loop or stall the boot process.
    exit "$RC"
fi
