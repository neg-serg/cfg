#!/usr/bin/env bash
set -euo pipefail

# Validate all Salt state files render without errors.
# Uses GNU parallel for concurrent validation.
#
# Usage: salt-validate.sh [JOBS] [-- TARGET...]
#   JOBS: max parallel jobs (default: nproc, or VALIDATE_JOBS env var)
#   TARGET: state name (desktop) or path (states/desktop.sls)
#   VALIDATE_TIMEOUT: per-state timeout in seconds (default: 300)

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"
script_dir="${project_dir}/scripts"
# shellcheck disable=SC1091
source "${script_dir}/salt-runtime.sh"

jobs="${VALIDATE_JOBS:-$(nproc)}"
validate_timeout="${VALIDATE_TIMEOUT:-300}"
salt_python="${project_dir}/.venv/bin/python3"

targets=()
if [[ $# -gt 0 && "$1" != "--" ]]; then
	jobs="$1"
	shift
fi
if [[ $# -gt 0 ]]; then
	if [[ "$1" != "--" ]]; then
		echo "error: explicit targets must follow --" >&2
		exit 1
	fi
	shift
	if [[ $# -eq 0 ]]; then
		echo "error: -- requires at least one target" >&2
		exit 1
	fi
	targets=("$@")
fi

if [[ ! -x "$salt_python" ]]; then
	echo "error: missing Salt venv interpreter at $salt_python" >&2
	echo "  run scripts/salt-apply.sh once to bootstrap .venv" >&2
	exit 1
fi

runtime="$(mktemp -d)"
salt_runtime_prepare_dirs "${project_dir}" "${runtime}"
salt_runtime_write_minion_config "${project_dir}" "${runtime}" validate

# Clear stale proc locks from previous runs
salt_runtime_clear_stale_proc_locks "${runtime}"
salt_runtime_reset_validate_cache "${runtime}"

# Use sudo when available (non-interactive sudo is needed for runas=)
sudo_cmd=""
if sudo -n true 2>/dev/null; then
	sudo_cmd="sudo"
fi

resolve_target() {
	local target="$1"
	local candidate

	if [[ "$target" == states/*.sls ]]; then
		if [[ -f "$target" ]]; then
			REPLY="$target"
			return 0
		fi
	else
		candidate="states/${target}.sls"
		if [[ -f "$candidate" ]]; then
			REPLY="$candidate"
			return 0
		fi
	fi

	echo "error: unknown state target: $target" >&2
	exit 1
}

collect_sls_files() {
	local target resolved
	declare -A seen_targets=()

	sls_files=()
	if [[ $# -eq 0 ]]; then
		shopt -s nullglob
		sls_files=(states/*.sls)
		shopt -u nullglob
		return 0
	fi

	for target in "$@"; do
		resolve_target "$target"
		resolved="$REPLY"
		if [[ -n "${seen_targets["$resolved"]+x}" ]]; then
			continue
		fi
		seen_targets["$resolved"]=1
		sls_files+=("$resolved")
	done
}

# --- Collect state names ---
collect_sls_files "${targets[@]}"

total=${#sls_files[@]}
if [[ $total -eq 0 ]]; then
	echo "Warning: no .sls files found in states/"
	exit 0
fi

# --- Pre-warm cache template ---
# Salt scans file_roots to build mtime_map (expensive for large trees).
# Build it once, then copy to per-worker caches so each starts warm.
cache_base=$(mktemp -d)
joblog=$(mktemp)
trap '$sudo_cmd rm -rf "$cache_base" "$runtime"; rm -f "$joblog"' EXIT

template_cache="${cache_base}/template"
mkdir -p "$template_cache"
$sudo_cmd "$salt_python" -m salt.scripts salt_call --local --config-dir="$runtime" \
	--cachedir="$template_cache" \
	state.show_sls audio --out=quiet 2>/dev/null || true

# --- Per-state validation function (exported for GNU parallel) ---
# Each worker copies the pre-warmed template cache for isolation.
validate_one() {
	local sls="$1"
	local slot="$2"
	local name="${sls#states/}"
	name="${name%.sls}"
	name="${name//\//.}"
	local worker_cache="${cache_base}/worker-${slot}"
	if [[ ! -d "$worker_cache" ]]; then
		$sudo_cmd cp -a "${cache_base}/template" "$worker_cache"
	fi
	if $sudo_cmd "$salt_python" -m salt.scripts salt_call --local --config-dir="$runtime" \
		--cachedir="$worker_cache" \
		state.show_sls "$name" --out=quiet 2>/dev/null; then
		return 0
	else
		echo "FAILED: $name"
		# Re-run to capture error details
		$sudo_cmd "$salt_python" -m salt.scripts salt_call --local --config-dir="$runtime" \
			--cachedir="$worker_cache" \
			state.show_sls "$name" --out=quiet 2>&1 || true
		return 1
	fi
}
export -f validate_one
export sudo_cmd cache_base runtime salt_python

# --- Parallel validation with joblog for accurate failure counting ---
# {1} and {#} are GNU parallel placeholders, not bash syntax
# shellcheck disable=SC1083
parallel --will-cite -j "$jobs" --group --timeout "$validate_timeout" --halt never \
	--joblog "$joblog" \
	validate_one {1} {#} ::: "${sls_files[@]}" || true

# Count failures from joblog (column 7 is Exitval, skip header line)
failed=$(awk 'NR>1 && $7!=0 {count++} END {print count+0}' "$joblog")

echo "Validated ${total} states, ${failed} failed"
[[ "$failed" -eq 0 ]]
