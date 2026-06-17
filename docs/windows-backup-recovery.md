# Windows Partition Backup Recovery

**Backup location:** `/mnt/one/windows-backup.zst` (404G, zstd -3)  
**Source:** `/dev/nvme0n1p2` (507G NTFS, "Windows")  
**Created:** 2026-06-16  

## Verify integrity

```bash
zstd -t /mnt/one/windows-backup.zst && echo "OK" || echo "CORRUPT"
```

## Restore to partition

```bash
# Restore to the SAME partition (507G+):
zstd -d -c /mnt/one/windows-backup.zst | sudo dd of=/dev/nvme0n1p2 bs=4M status=progress
```

## Restore to a different/new partition

```bash
# 1. Create partition (example: 507G)
sudo parted /dev/nvme0n1 mkpart primary ntfs 1049kB 507GB

# 2. Restore
zstd -d -c /mnt/one/windows-backup.zst | sudo dd of=/dev/nvme0n1p2 bs=4M status=progress
```

## Mount and browse without restoring

```bash
# Create loop device
sudo losetup -f --show /mnt/one/windows-backup.zst  # Note the loop device (e.g. /dev/loop0)

# Mount via ntfsclone
sudo ntfsclone --restore-image -o /dev/stdout /mnt/one/windows-backup.zst | \
  sudo ntfs-3g /dev/stdin /mnt/windows

# Or decompress + mount:
zstd -d -c /mnt/one/windows-backup.zst > /tmp/windows.img
sudo mount -t ntfs3 /tmp/windows.img /mnt/windows
```
