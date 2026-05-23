#!/usr/bin/env bash
# NixOS VM benchmark — measure build/eval times for comparison with Salt state-profiler
set -euo pipefail
NIX_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MODE="${1:-nochange}"

run_timed() {
  local label="$1" cmd="$2"
  local start end rc
  start=$(date +%s%N)
  eval "$cmd" >/dev/null 2>&1
  rc=$?
  end=$(date +%s%N)
  local ms=$(( (end - start) / 1000000 ))
  echo "$label: ${ms}ms (exit $rc)"
}

cd "$NIX_DIR"

case "$MODE" in
  fresh)
    nix store delete "$(nix build "path:.#nixosConfigurations.nixos.config.system.build.toplevel" --print-out-paths --no-link --no-warn-dirty 2>/dev/null | tail -1)" 2>/dev/null || true
    run_timed "fresh_eval"    "nix eval path:.#nixosConfigurations.nixos.config.system.build.toplevel.drvPath --no-warn-dirty"
    run_timed "fresh_build"   "nix build path:.#nixosConfigurations.nixos.config.system.build.toplevel --no-link --no-warn-dirty"
    ;;
  nochange)
    # Warm cache first
    nix build "path:.#nixosConfigurations.nixos.config.system.build.toplevel" --no-link --no-warn-dirty 2>/dev/null
    run_timed "nochange_eval"  "nix eval path:.#nixosConfigurations.nixos.config.system.build.toplevel.drvPath --no-warn-dirty"
    run_timed "nochange_build" "nix build path:.#nixosConfigurations.nixos.config.system.build.toplevel --no-link --no-warn-dirty"
    run_timed "nochange_vm"    "nix build path:.#nixosConfigurations.nixos.config.system.build.vm --no-link --no-warn-dirty"
    ;;
  delta)
    # Add a dummy env var, rebuild, revert
    echo '  CFG_TEST_MARKER = "benchmark";' >> "$NIX_DIR/modules/base.nix" || true
    run_timed "delta_build" "nix build path:.#nixosConfigurations.nixos.config.system.build.toplevel --no-link --no-warn-dirty"
    sed -i '/CFG_TEST_MARKER/d' "$NIX_DIR/modules/base.nix"
    run_timed "delta_revert" "nix build path:.#nixosConfigurations.nixos.config.system.build.toplevel --no-link --no-warn-dirty"
    ;;
  *)
    echo "Usage: $0 {fresh|nochange|delta}"
    exit 1
    ;;
esac
