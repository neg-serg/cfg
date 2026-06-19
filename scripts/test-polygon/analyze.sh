#!/bin/bash
# Compare fio benchmark results across filesystem configs
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
RESULTS_DIR="$SCRIPT_DIR/results"

usage() {
  cat <<EOF
Usage: analyze.sh [result-dirs...]

Compare fio results across filesystem configs. If no dirs given,
compares all result directories.

Examples:
  ./analyze.sh                           # compare all
  ./analyze.sh results/20250310-*xfs*    # only XFS results
EOF
  exit 0
}

if [ $# -gt 0 ]; then
  DIRS=("$@")
else
  DIRS=("$RESULTS_DIR"/*/)
fi

if [ ${#DIRS[@]} -eq 0 ]; then
  echo "No result directories found." >&2
  exit 1
fi

# Collect info per config
declare -A CONFIG_LABELS
declare -A CONFIG_FILES  # profile -> (config -> filepath)

echo "Results summary:"
printf -- '--- %.0s' {1..80}
echo

for d in "${DIRS[@]}"; do
  label=$(basename "$d")
  CONFIG_LABELS["$d"]="$label"

  # print info
  if [ -f "$d/info.txt" ]; then
    echo "Config: $(grep '^config:' "$d/info.txt" | cut -d' ' -f2-)"
    echo "  $(grep '^kernel:' "$d/info.txt" | cut -d' ' -f2-)"
    echo "  $(grep '^mkfs:' "$d/info.txt" | cut -d' ' -f2-)"
    echo "  $(grep '^mount:' "$d/info.txt" | cut -d' ' -f2-)"
  fi
  echo
done

printf -- '--- %.0s' {1..80}
echo

# For each profile, show comparison
profiles=()
for d in "${DIRS[@]}"; do
  for f in "$d"/*.json; do
    [ -f "$f" ] || continue
    pname=$(basename "$f" .json)
    [[ " ${profiles[*]} " =~ " $pname " ]] || profiles+=("$pname")
  done
done

for pname in "${profiles[@]}"; do
  echo
  echo "=== $pname ==="
  printf '%-30s %10s %12s %10s %10s %12s\n' "Config" "Read BW" "Read IOPS" "Write BW" "Write IOPS" "Latency p99"
  printf -- '-%.0s' {1..90}
  echo

  for d in "${DIRS[@]}"; do
    f="$d/$pname.json"
    [ -f "$f" ] || continue
    label=$(basename "$d")

    read_bw=$(jq -r '.jobs[0].read.bw / 1024 | floor' "$f" 2>/dev/null || echo "N/A")
    read_iops=$(jq -r '.jobs[0].read.iops | floor' "$f" 2>/dev/null || echo "N/A")
    write_bw=$(jq -r '.jobs[0].write.bw / 1024 | floor' "$f" 2>/dev/null || echo "N/A")
    write_iops=$(jq -r '.jobs[0].write.iops | floor' "$f" 2>/dev/null || echo "N/A")

    # p99 latency in usec
    lat_usec="N/A"
    for dir in read write; do
      lat=$(jq -r ".jobs[0].$dir.clat_ns.percentile.\"99.000000\" // empty" "$f" 2>/dev/null)
      if [ -n "$lat" ]; then
        lat_usec=$(echo "scale=0; $lat / 1000" | bc 2>/dev/null || echo "N/A")
        break
      fi
    done

    printf '%-30s %10s %12s %10s %10s %12s\n' "$label" "${read_bw}MB/s" "$read_iops" "${write_bw}MB/s" "$write_iops" "${lat_usec}us"
  done
done
