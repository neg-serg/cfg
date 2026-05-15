#!/usr/bin/env bash
# @script
# purpose: Generate Salt minion runtime configuration: reads file_roots from states/file_roots.yaml, creates minion config, and manages runtime directories. Called by salt-apply.sh.
#

set -euo pipefail

# Read file_roots from states/file_roots.yaml and output YAML block.
# Replaces hardcoded file_roots in minion config generation.
_salt_runtime_file_roots_block() {
    local project_dir="$1"
    local roots_file="${project_dir}/states/file_roots.yaml"

    if [[ ! -f "$roots_file" ]]; then
        printf 'file_roots:\n  base:\n    - %s/states/\n    - %s/\n' "$project_dir" "$project_dir"
        return
    fi

    printf 'file_roots:\n  base:\n'
    local in_base=0
    while IFS= read -r line; do
        case "$line" in
            base:) in_base=1; continue ;;
            *[a-zA-Z]*) ;;
        esac
        if [[ $in_base -eq 1 ]]; then
            line="${line#"${line%%[![:space:]]*}"}"
            line="${line#- }"
            line="${line//\$\{project_dir\}/${project_dir}}"
            if [[ -n "$line" ]]; then
                printf '    - %s\n' "$line"
            fi
        fi
    done < "$roots_file"
}


salt_runtime_prepare_dirs() {
    local project_dir="$1"
    local runtime_dir="$2"

    mkdir -p "${runtime_dir}/pki/minion" \
        "${runtime_dir}/var/cache/salt/pillar_cache" \
        "${runtime_dir}/var/cache/salt/files" \
        "${runtime_dir}/var/cache/salt/roots" \
        "${runtime_dir}/var/cache/salt/proc" \
        "${runtime_dir}/var/cache/salt/file_lists" \
        "${runtime_dir}/var/cache/salt/accumulator" \
        "${runtime_dir}/var/cache/salt/extrn_files" \
        "${runtime_dir}/var/log/salt"
}


salt_runtime_write_minion_config() {
    local project_dir="$1"
    local runtime_dir="$2"
    local mode="$3"
    local minion_path="${runtime_dir}/minion"

    case "$mode" in
        apply)
            cat > "${minion_path}" <<EOF
pki_dir: ${runtime_dir}/pki/minion
log_file: ${runtime_dir}/var/log/salt/minion
cachedir: ${runtime_dir}/var/cache/salt
minion_pillar_cache: True
pillar_cache: True
pillar_cache_backend: disk
pillar_cache_ttl: 3600
file_client: local
state_verbose: False
$(_salt_runtime_file_roots_block "$project_dir")

# --- Performance optimizations ---
enable_fqdns_grains: False
enable_gpu_grains: False
grains_cache: True
grains_cache_expiration: 3600
lazy_loader_strict_matching: True
autoload_dynamic_modules: True
fileserver_limit_traversal: True
fileserver_followsymlinks: False
process_count_max: 16
state_max_parallel: 8

# --- Grains overrides: map Arch derivatives so pkg module loads ---
grains:
  os_family: Arch
EOF
            ;;
        validate)
            cat > "${minion_path}" <<EOF
pki_dir: ${runtime_dir}/pki/minion
log_file: /dev/null
cachedir: ${runtime_dir}/var/cache/salt
file_client: local
state_verbose: False
$(_salt_runtime_file_roots_block "$project_dir")
enable_fqdns_grains: False
enable_gpu_grains: False
grains_cache: False
autoload_dynamic_modules: True
file_ignore_glob:
  - '*.pyc'
  - '.venv/*'
  - '.git/*'
  - '.salt_runtime/*'
  - 'specs/*'
  - '.specify/*'
  - 'node_modules/*'
EOF
            ;;
        *)
            echo "error: unknown salt runtime mode: ${mode}" >&2
            return 1
            ;;
    esac
}


salt_runtime_clear_stale_proc_locks() {
    local runtime_dir="$1"

    rm -rf "${runtime_dir}/var/cache/salt/proc/"*
}


salt_runtime_reset_validate_cache() {
    local runtime_dir="$1"
    local cache_root="${runtime_dir}/var/cache/salt"

    # Validation cache is ephemeral. Clear file/roots caches so foreign-owned
    # artifacts from previous sudo/runas executions cannot poison later renders.
    rm -rf \
        "${cache_root}/files" \
        "${cache_root}/roots" \
        "${cache_root}/proc" \
        "${cache_root}/file_lists" \
        "${cache_root}/accumulator" \
        "${cache_root}/extrn_files"

    mkdir -p \
        "${cache_root}/files" \
        "${cache_root}/roots" \
        "${cache_root}/proc" \
        "${cache_root}/file_lists" \
        "${cache_root}/accumulator" \
        "${cache_root}/extrn_files"
}
