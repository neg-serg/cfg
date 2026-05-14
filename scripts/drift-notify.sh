#!/usr/bin/env bash
# @script
# purpose: drift-notify.sh — run full drift check via drift_state.py and notify on drift
#

# drift-notify.sh — run full drift check via drift_state.py and notify on drift
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_DIR="${PROJECT_DIR}/logs"
LOG_FILE="${LOG_DIR}/drift-$(date +%F).log"

mkdir -p "$LOG_DIR"

# Run comprehensive drift check; exit 0 = clean, exit 1 = drift detected
if "${SCRIPT_DIR}/drift_state.py" full --project-dir "$PROJECT_DIR" > "$LOG_FILE" 2>&1; then
    exit 0
fi

# Drift detected — send desktop notification
if command -v notify-send &>/dev/null; then
    notify-send --urgency=normal \
        "Salt Drift" \
        "Drift detected. Run: just drift-status\nSee: ${LOG_FILE}"
fi

echo "Drift detected. Report: ${LOG_FILE}" >&2
exit 1
