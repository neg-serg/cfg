#!/bin/bash
# Btrfs RAID0 across 5 dm-linear slices of nvme0n1p2
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
RESULTS_DIR="$SCRIPT_DIR/results"
PROFILES_DIR="$SCRIPT_DIR/profiles"
DEV=/dev/nvme0n1p2
NDISKS=5
SIZE_SECTORS=209715200  # 100 GiB in 512B sectors
DM_PREFIX=btrfs-r0
MOUNT_POINT=/mnt/test-raid0
LABEL="btrfs-raid0-dm"
FIO_GLOBALS=(--size=5G --runtime=30 --time_based --group_reporting --direct=1 --ioengine=libaio --fallocate=none --norandommap)

say() { printf '\n=== %s ===\n' "$*"; }

cleanup() {
  set +e
  mountpoint -q "$MOUNT_POINT" 2>/dev/null && umount "$MOUNT_POINT"
  for i in $(seq 0 $((NDISKS - 1))); do
    dmsetup remove "${DM_PREFIX}p$i" 2>/dev/null
  done
  [ -d "$MOUNT_POINT" ] && rmdir "$MOUNT_POINT" 2>/dev/null
  set -e
}

if [ "$(id -u)" -ne 0 ]; then
  echo "Error: run as root" >&2
  exit 1
fi

trap cleanup EXIT
cleanup

# 1. Clear stale O_EXCL on the partition
python3 -c "import os; fd=os.open('$DEV', os.O_RDWR); os.close(fd)" 2>/dev/null || true

# 2. Create 5 dm-linear devices (100 GiB each) slicing the partition
say "Creating $NDISKS dm-linear slices"
for i in $(seq 0 $((NDISKS - 1))); do
  offset=$((i * SIZE_SECTORS))
  name="${DM_PREFIX}p$i"
  dmsetup create "$name" --table "0 $SIZE_SECTORS linear $DEV $offset"
  echo "  $name: offset=${offset}sectors, size=${SIZE_SECTORS}sectors ($((SIZE_SECTORS * 512 / 1073741824))G)"
done

DM_DEVS=()
for i in $(seq 0 $((NDISKS - 1))); do
  DM_DEVS+=("/dev/mapper/${DM_PREFIX}p$i")
done

# 3. mkfs btrfs RAID0 on dm slices
say "mkfs.btrfs -d raid0 -m raid0 on ${DM_DEVS[*]}"
mkfs.btrfs -f --nodiscard -d raid0 -m raid0 -L "$LABEL" "${DM_DEVS[@]}"

# 4. mount
mkdir -p "$MOUNT_POINT"
mount -t btrfs -o noatime,ssd "${DM_DEVS[0]}" "$MOUNT_POINT"

# 5. run benchmarks
label_dir="$RESULTS_DIR/$(date +%Y%m%d-%H%M%S)-$LABEL"
mkdir -p "$label_dir"

{
  echo "config: $LABEL"
  echo "device: $DEV (5 × $((SIZE_SECTORS * 512 / 1073741824))G dm-linear slices)"
  echo "mkfs: mkfs.btrfs -d raid0 -m raid0 on ${DM_DEVS[*]}"
  echo "mount: -o noatime,ssd"
  echo "date: $(date -Iseconds)"
  echo "kernel: $(uname -r)"
} > "$label_dir/info.txt"

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

  rm -f "$testfile"
done

# 6. metadata
df -h "$MOUNT_POINT" > "$label_dir/df.txt"
btrfs filesystem show > "$label_dir/btrfs_show.txt" 2>&1
btrfs filesystem usage "$MOUNT_POINT" > "$label_dir/btrfs_usage.txt" 2>&1

say "Done: $LABEL (results in $(basename "$label_dir"))"
say "ALL BENCHMARKS COMPLETE"
