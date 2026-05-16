#!/usr/bin/env bash
# Apply critical Salt states at boot (group/core).
# Called by salt-boot-apply.service as a oneshot.
set -euo pipefail

PROJECT_DIR="${1:-/home/neg/src/cfg}"
SALT_CALL="${PROJECT_DIR}/.venv/bin/salt-call"
RUNTIME_DIR="${PROJECT_DIR}/.salt_runtime"

if [ ! -x "${SALT_CALL}" ]; then
    echo "salt-call not found at ${SALT_CALL}, skipping boot apply" >&2
    exit 0
fi

LOG_DIR="${PROJECT_DIR}/logs"
mkdir -p "${LOG_DIR}"
TS="$(date +%Y%m%d-%H%M%S)"
LOG="${LOG_DIR}/salt_boot_apply-${TS}.log"

# Sync custom modules before rendering states
"${SALT_CALL}" --local --config-dir="${RUNTIME_DIR}" saltutil.sync_all >/dev/null 2>&1 || true

"${SALT_CALL}" --local --retcode-passthrough \
    --config-dir="${RUNTIME_DIR}" \
    state.apply group/core \
    >"${LOG}" 2>&1

rc=$?
if [ $rc -ne 0 ]; then
    echo "salt-boot-apply FAILED (exit $rc): group/core, see ${LOG}" >&2
    exit 1
fi

echo "salt-boot-apply OK: group/core applied, log ${LOG}"
