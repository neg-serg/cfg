#!/usr/bin/env bash
# @script
# purpose: health-check.sh — check health of all Salt-managed services
#

# health-check.sh — check health of all Salt-managed services
#
# Usage:
#   scripts/health-check.sh            # colored table
#   scripts/health-check.sh --json     # JSON output
#   scripts/health-check.sh --quiet    # exit code only (0=healthy, 1=unhealthy)

set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "${project_dir}/scripts/lib/pretty.sh" 2>/dev/null || true

JSON_MODE=false
QUIET_MODE=false

for arg in "$@"; do
	case "$arg" in
	--json) JSON_MODE=true ;;
	--quiet | -q) QUIET_MODE=true ;;
	*)
		echo "Unknown arg: $arg" >&2
		exit 1
		;;
	esac
done

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
host_name=$(hostnamectl --static 2>/dev/null || hostname)

unhealthy=0
results=()

check_system_service() {
	local svc="$1"
	local expected="${2:-active}"
	local actual
	actual=$(systemctl show -p ActiveState --value "$svc" 2>/dev/null || echo "inactive")
	local status="healthy"
	if [ "$actual" != "$expected" ]; then
		status="unhealthy"
		unhealthy=$((unhealthy + 1))
	fi
	results+=("$(printf '%s\t%s\t%s\t%s\t%s\t%s' "$svc" "system" "$expected" "$actual" "-" "$status")")
}

check_user_service() {
	local svc="$1"
	local expected="${2:-active}"
	local actual
	actual=$(systemctl --user show -p ActiveState --value "$svc" 2>/dev/null || echo "inactive")
	if [ "$expected" = "active (waiting)" ] && [ "$actual" = "active" ]; then
		actual="active (waiting)"
	fi
	local status="healthy"
	if [ "$actual" != "$expected" ]; then
		status="unhealthy"
		unhealthy=$((unhealthy + 1))
	fi
	results+=("$(printf '%s\t%s\t%s\t%s\t%s\t%s' "$svc" "user" "$expected" "$actual" "-" "$status")")
}

# ── System services ──────────────────────────────────────────────────────
SYSTEM_SERVICES=(
	sshd
	NetworkManager
)

# Optional system services (may not be installed)
OPTIONAL_SYSTEM=(
	jellyfin-container
	transmission-container
	adguardhome-container
	cronie
	ollama
	llama-embed
	netdata
	samba
	bitcoind-container
)

if python3 - "$PROJECT_DIR" "$host_name" <<'PY'; then
import sys
from pathlib import Path

import yaml

project_dir = Path(sys.argv[1])
host_name = sys.argv[2].strip()
data = yaml.safe_load((project_dir / 'states' / 'data' / 'hosts.yaml').read_text()) or {}
defaults = data.get('defaults', {})
hosts = data.get('hosts', {})
aliases = data.get('aliases', {})
resolved = aliases.get(host_name, host_name)
host = defaults.copy()

def merge(base, override):
    result = dict(base)
    for key, value in override.items():
        if isinstance(result.get(key), dict) and isinstance(value, dict):
            result[key] = merge(result[key], value)
        else:
            result[key] = value
    return result

host = merge(host, hosts.get(resolved, {}))
print('true' if host.get('features', {}).get('dns', {}).get('unbound', False) else 'false')
PY
	:
fi

if [ "$(
	python3 - "$PROJECT_DIR" "$host_name" <<'PY'
import sys
from pathlib import Path

import yaml

project_dir = Path(sys.argv[1])
host_name = sys.argv[2].strip()
data = yaml.safe_load((project_dir / 'states' / 'data' / 'hosts.yaml').read_text()) or {}
defaults = data.get('defaults', {})
hosts = data.get('hosts', {})
aliases = data.get('aliases', {})
resolved = aliases.get(host_name, host_name)

def merge(base, override):
    result = dict(base)
    for key, value in override.items():
        if isinstance(result.get(key), dict) and isinstance(value, dict):
            result[key] = merge(result[key], value)
        else:
            result[key] = value
    return result

host = merge(defaults, hosts.get(resolved, {}))
print('true' if host.get('features', {}).get('dns', {}).get('unbound', False) else 'false')
PY
)" = "true" ]; then
	SYSTEM_SERVICES+=("unbound")
fi

if [ "$(
	python3 - "$PROJECT_DIR" "$host_name" <<'PY'
import sys
from pathlib import Path

import yaml

project_dir = Path(sys.argv[1])
host_name = sys.argv[2].strip()
data = yaml.safe_load((project_dir / 'states' / 'data' / 'hosts.yaml').read_text()) or {}
defaults = data.get('defaults', {})
hosts = data.get('hosts', {})
aliases = data.get('aliases', {})
resolved = aliases.get(host_name, host_name)

def merge(base, override):
    result = dict(base)
    for key, value in override.items():
        if isinstance(result.get(key), dict) and isinstance(value, dict):
            result[key] = merge(result[key], value)
        else:
            result[key] = value
    return result

host = merge(defaults, hosts.get(resolved, {}))
print('true' if host.get('features', {}).get('monitoring', {}).get('alerts', False) else 'false')
PY
)" = "true" ]; then
	SYSTEM_SERVICES+=("cronie")
fi

if [ "$(
	python3 - "$PROJECT_DIR" "$host_name" <<'PY'
import sys
from pathlib import Path

import yaml

project_dir = Path(sys.argv[1])
host_name = sys.argv[2].strip()
data = yaml.safe_load((project_dir / 'states' / 'data' / 'hosts.yaml').read_text()) or {}
defaults = data.get('defaults', {})
hosts = data.get('hosts', {})
aliases = data.get('aliases', {})
resolved = aliases.get(host_name, host_name)

def merge(base, override):
    result = dict(base)
    for key, value in override.items():
        if isinstance(result.get(key), dict) and isinstance(value, dict):
            result[key] = merge(result[key], value)
        else:
            result[key] = value
    return result

host = merge(defaults, hosts.get(resolved, {}))
print('true' if host.get('features', {}).get('monitoring', {}).get('loki', False) else 'false')
PY
)" = "true" ]; then
	OPTIONAL_SYSTEM+=("loki-container")
fi

if [ "$(
	python3 - "$PROJECT_DIR" "$host_name" <<'PY'
import sys
from pathlib import Path

import yaml

project_dir = Path(sys.argv[1])
host_name = sys.argv[2].strip()
data = yaml.safe_load((project_dir / 'states' / 'data' / 'hosts.yaml').read_text()) or {}
defaults = data.get('defaults', {})
hosts = data.get('hosts', {})
aliases = data.get('aliases', {})
resolved = aliases.get(host_name, host_name)

def merge(base, override):
    result = dict(base)
    for key, value in override.items():
        if isinstance(result.get(key), dict) and isinstance(value, dict):
            result[key] = merge(result[key], value)
        else:
            result[key] = value
    return result

host = merge(defaults, hosts.get(resolved, {}))
print('true' if host.get('features', {}).get('monitoring', {}).get('promtail', False) else 'false')
PY
)" = "true" ]; then
	OPTIONAL_SYSTEM+=("promtail-container")
fi

if [ "$(
	python3 - "$PROJECT_DIR" "$host_name" <<'PY'
import sys
from pathlib import Path

import yaml

project_dir = Path(sys.argv[1])
host_name = sys.argv[2].strip()
data = yaml.safe_load((project_dir / 'states' / 'data' / 'hosts.yaml').read_text()) or {}
defaults = data.get('defaults', {})
hosts = data.get('hosts', {})
aliases = data.get('aliases', {})
resolved = aliases.get(host_name, host_name)

def merge(base, override):
    result = dict(base)
    for key, value in override.items():
        if isinstance(result.get(key), dict) and isinstance(value, dict):
            result[key] = merge(result[key], value)
        else:
            result[key] = value
    return result

host = merge(defaults, hosts.get(resolved, {}))
print('true' if host.get('features', {}).get('monitoring', {}).get('grafana', False) else 'false')
PY
)" = "true" ]; then
	OPTIONAL_SYSTEM+=("grafana-container")
fi

for svc in "${SYSTEM_SERVICES[@]}"; do
	check_system_service "$svc"
done

for svc in "${OPTIONAL_SYSTEM[@]}"; do
	# Only check if the unit file exists
	if systemctl cat "$svc" &>/dev/null; then
		check_system_service "$svc"
	fi
done

# ── User services ────────────────────────────────────────────────────────
# Parse from user_services.yaml
USER_SERVICES_FILE="${PROJECT_DIR}/states/data/user_services.yaml"
if [ -f "$USER_SERVICES_FILE" ]; then
	while IFS= read -r svc; do
		if [ -n "$svc" ] && [ "$svc" != "openrgb-profile.service" ]; then
			check_user_service "$svc"
		fi
	done < <(sed -n '/^enable_services:/,/^[^ ]/p' "$USER_SERVICES_FILE" | grep -v 'features:' | grep -oP '^\s+- \{name:\s*\K[^,}]+' 2>/dev/null || true)

	# Enabled oneshot services settle back to inactive after a successful run.
	check_user_service "openrgb-profile.service" "inactive"

	while IFS= read -r timer; do
		[ -n "$timer" ] && check_user_service "$timer" "active (waiting)"
	done < <(sed -n '/^enable_now_timers:/,/^[^ ]/p' "$USER_SERVICES_FILE" | grep -v 'features:' | grep -oP '^\s+- \{name:\s*\K[^,}]+' 2>/dev/null || true)
fi

# ── HTTP healthchecks ────────────────────────────────────────────────────
declare -A HEALTHCHECKS=(
	[ollama]="11434:/api/tags"
)

# Dash-delimited unit names are assigned explicitly here so the runtime map
# matches the actual systemd service names used elsewhere in the repo.
HEALTHCHECKS["loki-container"]="3100:/ready"
HEALTHCHECKS["promtail-container"]="9080:/ready"
HEALTHCHECKS["grafana-container"]="3030:/api/health"
HEALTHCHECKS["adguardhome-container"]="3000:/"
HEALTHCHECKS["llama-embed"]="11435:/health"

for name in "${!HEALTHCHECKS[@]}"; do
	IFS=: read -r port path <<<"${HEALTHCHECKS[$name]}"
	# Find the matching result entry and add health info
	for i in "${!results[@]}"; do
		entry="${results[$i]}"
		entry_name="${entry%%	*}"
		if [ "$entry_name" = "$name" ]; then
			http_ok="-"
			status=$(echo "$entry" | cut -f6)
			if curl -sf --connect-timeout 2 --max-time 5 "http://127.0.0.1:${port}${path}" >/dev/null 2>&1; then
				http_ok="ok"
			else
				entry_actual=$(echo "$entry" | cut -f4)
				if [ "$entry_actual" = "active" ]; then
					http_ok="FAIL"
					status="unhealthy"
					unhealthy=$((unhealthy + 1))
				else
					http_ok="skip"
				fi
			fi
			# Replace the health and status fields (fields 5 and 6)
			results[i]=$(echo "$entry" | awk -F'\t' -v h="$http_ok" -v s="$status" 'BEGIN{OFS="\t"} {$5=h; $6=s; print}')
			break
		fi
	done
done

# ── Output ───────────────────────────────────────────────────────────────
if $QUIET_MODE; then
	exit $((unhealthy > 0 ? 1 : 0))
fi

if $JSON_MODE; then
	echo "["
	first=true
	for entry in "${results[@]}"; do
		IFS=$'\t' read -r name type expected actual health status <<<"$entry"
		$first || echo ","
		first=false
		printf '  {"service":"%s","type":"%s","expected":"%s","actual":"%s","health":"%s","status":"%s"}' \
			"$name" "$type" "$expected" "$actual" "$health" "$status"
	done
	echo ""
	echo "]"
	exit $((unhealthy > 0 ? 1 : 0))
fi

# Table output — use pretty::service_status if available
if declare -f pretty::header >/dev/null 2>&1; then
    pretty::section "Service Health"
fi
for entry in "${results[@]}"; do
    IFS=$'\t' read -r name _ _ _ _ status <<<"$entry"
    if declare -f pretty::service_status >/dev/null 2>&1; then
        pretty::service_status "$name" "$status"
    else
        case "$status" in
            healthy) printf '  \033[32m%-40s active\033[0m\n' "$name" ;;
            *)       printf '  \033[31m%-40s failed\033[0m\n' "$name" ;;
        esac
    fi
done

echo ""
if declare -f pretty::ok >/dev/null 2>&1; then
    if [ "$unhealthy" -eq 0 ]; then
        pretty::ok "All services healthy"
    else
        pretty::fail "${unhealthy} unhealthy service(s)"
    fi
else
    if [ "$unhealthy" -eq 0 ]; then
        printf '%b%s%b\n' "$GREEN" "All services healthy" "$NC"
    else
        printf '%b%d unhealthy service(s)%b\n' "$RED" "$unhealthy" "$NC"
    fi
fi

exit $((unhealthy > 0 ? 1 : 0))
