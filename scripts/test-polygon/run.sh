#!/bin/bash
# Test polygon runner — reformats nvme0n1p2 with each fs config and runs fio benchmarks
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
RESULTS_DIR="$SCRIPT_DIR/results"
CONFIGS_DIR="$SCRIPT_DIR/configs"
PROFILES_DIR="$SCRIPT_DIR/profiles"
DEVICE=/dev/nvme0n1p2
MOUNT_POINT=/mnt/test-polygon
FIO_GLOBALS=(--size=5G --runtime=30 --time_based --group_reporting --direct=1 --ioengine=libaio --fallocate=none --norandommap)

say() { printf '\n=== %s ===\n' "$*"; }

usage() {
  cat <<EOF
Usage: run.sh [config...]

Run benchmarks for specified configs (or all if none given).

Examples:
  sudo ./run.sh                                    # all configs
  sudo ./run.sh xfs-rmapbt-on btrfs-default        # selected configs
  sudo ./run.sh xfs-*                              # all XFS configs

Available configs:
EOF
  for f in "$CONFIGS_DIR"/*.sh; do
    echo "  $(basename "${f%.sh}")"
  done
  exit 0
}

if [ $# -eq 0 ]; then
  CONFIGS=("$CONFIGS_DIR"/*.sh)
else
  CONFIGS=()
  for name in "$@"; do
    f="$CONFIGS_DIR/$name.sh"
    if [ -f "$f" ]; then
      CONFIGS+=("$f")
    else
      echo "Error: config '$name' not found" >&2
      exit 1
    fi
  done
fi

if [ "$(id -u)" -ne 0 ]; then
  echo "Error: run as root (needs mkfs + mount)" >&2
  exit 1
fi

mkdir -p "$RESULTS_DIR"

for config_sh in "${CONFIGS[@]}"; do
  unset FSTYPE LABEL MKFS_OPTS MOUNT_OPTS
  source "$config_sh"

  say "Preparing: $LABEL"

  # unmount if mounted elsewhere
  if mountpoint -q "$MOUNT_POINT" 2>/dev/null; then
    umount "$MOUNT_POINT"
  fi
  if mount | grep -q "$DEVICE"; then
    umount "$DEVICE"
  fi

  # mkfs
  say "mkfs.$FSTYPE on $DEVICE -> $LABEL"
  case "$FSTYPE" in
    xfs)
      mkfs.xfs -f "${MKFS_OPTS[@]}" -L "$LABEL" "$DEVICE"
      ;;
    btrfs)
      mkfs.btrfs -f "${MKFS_OPTS[@]}" -L "$LABEL" "$DEVICE"
      ;;
    *)
      echo "Unknown FSTYPE: $FSTYPE" >&2
      exit 1
  esac

  # mount
  mkdir -p "$MOUNT_POINT"
  mount -t "$FSTYPE" -o "${MOUNT_OPTS[*]}" "$DEVICE" "$MOUNT_POINT"
  label_dir="$RESULTS_DIR/$(date +%Y%m%d-%H%M%S)-$LABEL"
  mkdir -p "$label_dir"

  # save mkfs + mount info
  {
    echo "config: $LABEL"
    echo "device: $DEVICE"
    echo "mkfs: mkfs.$FSTYPE ${MKFS_OPTS[*]}"
    echo "mount: -o ${MOUNT_OPTS[*]}"
    echo "date: $(date -Iseconds)"
    echo "kernel: $(uname -r)"
  } > "$label_dir/info.txt"

  # run all profiles
  for profile in "$PROFILES_DIR"/*.fio; do
    name=$(basename "$profile" .fio)
    testfile="$MOUNT_POINT/__fio-$name"

    say "  fio profile: $name"

    fio "$profile" \
      "${FIO_GLOBALS[@]}" \
      --filename="$testfile" \
      --output-format=json \
      --output="$label_dir/$name.json" \
      --lat_percentiles=1 \
      --percentile_list=50:90:99:99.9:99.99

    # clean up test file
    rm -f "$testfile"
  done

  # filesystem metadata (df + fs-specific info)
  df -h "$DEVICE" > "$label_dir/df.txt"
  case "$FSTYPE" in
    xfs) xfs_info "$DEVICE" > "$label_dir/xfs_info.txt" 2>&1 ;;
    btrfs) btrfs filesystem show "$DEVICE" > "$label_dir/btrfs_show.txt" 2>&1
           btrfs filesystem usage "$MOUNT_POINT" > "$label_dir/btrfs_usage.txt" 2>&1 ;;
  esac

  umount "$MOUNT_POINT"

  say "Done: $LABEL (results in $(basename "$label_dir"))"
done

say "ALL BENCHMARKS COMPLETE"
echo "Results in: $RESULTS_DIR"
