#!/usr/bin/env bash
# @script
# purpose: Validate all Salt state files render without errors.
#

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
# shellcheck disable=SC1091
source "${script_dir}/lib/pretty.sh" 2>/dev/null || true

jobs="${VALIDATE_JOBS:-$(nproc)}"
validate_timeout="${VALIDATE_TIMEOUT:-300}"
salt_python="${project_dir}/.venv/bin/python3"
summary_file="${VALIDATE_SUMMARY_FILE:-}"

json_escape() {
	local value="$1"
	value=${value//\\/\\\\}
	value=${value//\"/\\\"}
	value=${value//$'\n'/\\n}
	value=${value//$'\r'/\\r}
	value=${value//$'\t'/\\t}
	printf '%s' "$value"
}

write_failure_bundle() {
	local state="$1"
	local entrypoint="$2"
	local error="$3"
	local output_dir="${SALT_DEBUG_REPORT_DIR:-logs/debug}"
	local timestamp
	local sanitized_state
	local bundle_path

	if [[ -z "$error" ]]; then
		error="salt validation failed"
	fi

	mkdir -p "$output_dir"
	timestamp="$(date -u +%Y%m%dT%H%M%S)"
	sanitized_state="${state//\//-}"
	bundle_path="${output_dir}/${timestamp}-salt-validate-${sanitized_state}.json"

	printf '{\n  "tool": "salt-validate",\n  "state": "%s",\n  "entrypoint": %s,\n  "failure_stage": "render",\n  "error": "%s"\n}\n' \
		"$(json_escape "$state")" \
		"$entrypoint" \
		"$(json_escape "$error")" > "$bundle_path"
}

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
		shopt -s globstar nullglob
		sls_files=(states/**/*.sls)
		shopt -u globstar nullglob
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

if [[ -z "$summary_file" ]]; then
	mkdir -p logs
	summary_file="logs/salt-validate-$(date +%Y%m%d-%H%M%S).json"
else
	mkdir -p "$(dirname "$summary_file")"
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
	local entrypoint=true
	local error_output=""
	name="${name%.sls}"
	if [[ "$name" == */* ]]; then
		entrypoint=false
	fi
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
		error_output="$($sudo_cmd "$salt_python" -m salt.scripts salt_call --local --config-dir="$runtime" \
			--cachedir="$worker_cache" \
			state.show_sls "$name" --out=quiet 2>&1 || true)"
		if [[ -n "$error_output" ]]; then
			printf '%s\n' "$error_output"
		fi
		write_failure_bundle "$name" "$entrypoint" "$error_output"
		return 1
	fi
}
export -f validate_one
export -f json_escape write_failure_bundle
export sudo_cmd cache_base runtime salt_python

# --- Parallel validation with joblog for accurate failure counting ---
# {1} and {#} are GNU parallel placeholders, not bash syntax
# shellcheck disable=SC1083
parallel --will-cite -j "$jobs" --group --timeout "$validate_timeout" --halt never \
	--joblog "$joblog" \
	validate_one {1} {#} ::: "${sls_files[@]}" || true

# Count failures from joblog (column 7 is Exitval, skip header line)
failed=$(awk 'NR>1 && $7!=0 {count++} END {print count+0}' "$joblog")

write_summary_artifact() {
	local results_json=""
	local line_no=0
	while IFS=$'\t' read -r _ _ _ _ _ _ exitval _ command; do
		if [[ $line_no -eq 0 ]]; then
			line_no=$((line_no + 1))
			continue
		fi
		local target="${command#validate_one }"
		target="${target% *}"
		local state="${target#states/}"
		state="${state%.sls}"
		state="${state//\//.}"
		local success=false
		if [[ "$exitval" -eq 0 ]]; then
			success=true
		fi
		local entry
		entry=$(printf '{"state":"%s","success":%s}' "$(json_escape "$state")" "$success")
		if [[ -n "$results_json" ]]; then
			results_json+="," 
		fi
		results_json+="$entry"
		line_no=$((line_no + 1))
	done < "$joblog"

	printf '{\n  "tool": "salt-validate",\n  "total": %s,\n  "failed": %s,\n  "results": [%s]\n}\n' \
		"$total" \
		"$failed" \
		"$results_json" > "$summary_file"
}

write_summary_artifact

if declare -f pretty::ok >/dev/null 2>&1; then
    if [[ "$failed" -eq 0 ]]; then
        pretty::ok "All ${total} states valid"
    else
        pretty::fail "${failed}/${total} states failed"
        while IFS=$'\t' read -r _ _ _ _ _ _ exitval _ command; do
            [[ $exitval -ne 0 && "$command" != *"Seq"* ]] || continue
            local target="${command#validate_one }"
            target="${target% *}"
            pretty::info "  ${target}"
        done < "$joblog"
    fi
else
    echo "Validated ${total} states, ${failed} failed"
fi
[[ "$failed" -eq 0 ]]
