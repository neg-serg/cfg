FSTYPE=btrfs
LABEL="btrfs-compress-zstd"
MKFS_OPTS=()
MOUNT_OPTS=(noatime ssd compress=zstd)
