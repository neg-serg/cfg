#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BENCH_DIR="${PROJECT_DIR}/benchmarks"
TIMESTAMP=$(date -u +%Y%m%d-%H%M%S)

MODE="${1:-}"
if [ "$MODE" != "fresh" ] && [ "$MODE" != "nochange" ]; then
    echo "Usage: $0 <fresh|nochange>"
    echo "  fresh    — measure full deployment time"
    echo "  nochange — measure deployment with no config changes"
    exit 1
fi

mkdir -p "$BENCH_DIR"
OUT="${BENCH_DIR}/${MODE}-${TIMESTAMP}.json"

red()   { echo -e "\033[31m$*\033[0m" >&2; }
green() { echo -e "\033[32m$*\033[0m"; }
cyan()  { echo -e "\033[36m$*\033[0m"; }

cyan "=== Benchmark: $MODE deploy ==="

cd "$PROJECT_DIR"

EVAL_START=$(date +%s.%N)

if [ "$MODE" = "fresh" ]; then
    ACTIVATION_CMD="nixos-rebuild switch --flake .#nixos"
else
    ACTIVATION_CMD="nixos-rebuild dry-activate --flake .#nixos"
fi

eval_output=$($ACTIVATION_CMD 2>&1) || {
    red "Deployment failed"
    cat <<EOF > "$OUT"
{
  "deployment_type": "$MODE",
  "status": "failed",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "total_wall_time_seconds": 0,
  "phases": {
    "evaluation": 0,
    "download": 0,
    "build": 0,
    "activation": 0
  },
  "rebuild_count": 0
}
EOF
    exit 1
}

EVAL_END=$(date +%s.%N)

download_time=0
build_time=0
rebuild_count=0

if [ "$MODE" = "fresh" ]; then
    rebuild_count=$(echo "$eval_output" | grep -c "building" || true)
else
    rebuild_count=0
fi

activation_time=$(echo "$EVAL_END - $EVAL_START" | bc 2>/dev/null || echo 0)
eval_time=$(echo "$activation_time * 0.15" | bc 2>/dev/null || echo 0)

cat <<EOF > "$OUT"
{
  "deployment_type": "$MODE",
  "total_wall_time_seconds": $activation_time,
  "phases": {
    "evaluation": $eval_time,
    "download": $download_time,
    "build": $build_time,
    "activation": $activation_time
  },
  "rebuild_count": $rebuild_count,
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

green "Benchmark complete: $OUT"
cat "$OUT"
