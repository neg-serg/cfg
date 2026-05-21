#!/usr/bin/env bash
# @script
# purpose: SUDO_ASKPASS helper — resolvs sudo pwd from gopass, fallback to .password
#
# Usage: SUDO_ASKPASS=scripts/salt-askpass.sh sudo -A <command>
set -euo pipefail

SCRIPT_DIR="${0%/*}"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Prefer gopass
if command -v gopass &>/dev/null; then
    for key in host/sudo-password host/password; do
        if password=$(gopass show -o "$key" 2>/dev/null) && [[ -n "$password" ]]; then
            echo "$password"
            exit 0
        fi
    done
fi

# Fallback: existing .password file
if [[ -f "$PROJECT_DIR/.password" ]]; then
    cat "$PROJECT_DIR/.password"
    exit 0
fi

exit 1
