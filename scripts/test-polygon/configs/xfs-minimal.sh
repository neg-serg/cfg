FSTYPE=xfs
LABEL="xfs-minimal"
MKFS_OPTS=(-m crc=1 -m reflink=0 -m rmapbt=0)
MOUNT_OPTS=(noatime)
