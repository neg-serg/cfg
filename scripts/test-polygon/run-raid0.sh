#!/bin/bash
# Btrfs RAID0 across 5 loop devices on nvme0n1p2
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
RESULTS_DIR="$SCRIPT_DIR/results"
PROFILES_DIR="$SCRIPT_DIR/profiles"
BACKING_DEV=/dev/nvme0n1p2
BACKING_MNT=/mnt/test-polygon-backing
RAID0_MNT=/mnt/test-raid0
LABEL="btrfs-raid0-loop"
NDISKS=5
DISK_SIZE=100G
LOOP_BASE=/dev/loop200
FIO_GLOBALS=(--size=5G --runtime=30 --time_based --group_reporting --direct=1 --ioengine=libaio --fallocate=none --norandommap)

say() { printf '\n=== %s ===\n' "$*"; }

cleanup() {
  set +e
  mountpoint -q "$RAID0_MNT" 2>/dev/null && umount "$RAID0_MNT"
  for i in $(seq 0 $((NDISKS - 1))); do
    losetup "${LOOP_BASE}$i" 2>/dev/null && losetup -d "${LOOP_BASE}$i"
  done
  mountpoint -q "$BACKING_MNT" 2>/dev/null && umount "$BACKING_MNT"
  [ -d "$BACKING_MNT" ] && rmdir "$BACKING_MNT" 2>/dev/null
  [ -d "$RAID0_MNT" ] && rmdir "$RAID0_MNT" 2>/dev/null
  set -e
}

if [ "$(id -u)" -ne 0 ]; then
  echo "Error: run as root" >&2
  exit 1
fi

trap cleanup EXIT
cleanup

# 1. mount backing device (XFS for efficient sparse file storage)
say "Format backing device"
python3 -c "import os; fd=os.open('$BACKING_DEV', os.O_RDWR); os.close(fd)" 2>/dev/null || true
for _ in 1 2 3; do
  mkfs.xfs -f -K -L r0backing "$BACKING_DEV" && break
  python3 -c "import os; fd=os.open('$BACKING_DEV', os.O_RDWR); os.close(fd)" 2>/dev/null || true
  sleep 3
done
mkdir -p "$BACKING_MNT"
mount -t xfs -o noatime,nodiscard "$BACKING_DEV" "$BACKING_MNT"

# 2. create sparse backing files + loop devices
say "Creating $NDISKS × $DISK_SIZE loop devices"
LOOP_DEVS=()
for i in $(seq 0 $((NDISKS - 1))); do
  f="$BACKING_MNT/disk$i.img"
  truncate -s "$DISK_SIZE" "$f"
  losetup "$LOOP_BASE$i" "$f"
  LOOP_DEVS+=("$LOOP_BASE$i")
done

# 3. mkfs btrfs RAID0
say "mkfs.btrfs -d raid0 -m raid0 on ${LOOP_DEVS[*]}"
mkfs.btrfs -f --nodiscard -d raid0 -m raid0 -L "$LABEL" "${LOOP_DEVS[@]}"

# 4. mount raid0
mkdir -p "$RAID0_MNT"
mount -t btrfs -o noatime,ssd "${LOOP_BASE}0" "$RAID0_MNT"

# 5. run benchmarks
label_dir="$RESULTS_DIR/$(date +%Y%m%d-%H%M%S)-$LABEL"
mkdir -p "$label_dir"

{
  echo "config: $LABEL"
  echo "backing: $BACKING_DEV"
  echo "disks: $NDISKS × $DISK_SIZE loop devices on XFS backing"
  echo "mkfs: mkfs.btrfs -d raid0 -m raid0 on ${LOOP_DEVS[*]}"
  echo "mount: -o noatime,ssd"
  echo "date: $(date -Iseconds)"
  echo "kernel: $(uname -r)"
} > "$label_dir/info.txt"

for profile in "$PROFILES_DIR"/*.fio; do
  name=$(basename "$profile" .fio)
  testfile="$RAID0_MNT/__fio-$name"

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

# 6. filesystem metadata
df -h "$RAID0_MNT" > "$label_dir/df.txt"
btrfs filesystem show > "$label_dir/btrfs_show.txt" 2>&1
btrfs filesystem usage "$RAID0_MNT" > "$label_dir/btrfs_usage.txt" 2>&1

say "Done: $LABEL (results in $(basename "$label_dir"))"
say "ALL BENCHMARKS COMPLETE"
echo "Results in: $label_dir"
