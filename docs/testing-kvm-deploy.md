# KVM Deployment Testing

End-to-end verification that Salt states produce a working CachyOS deployment.

## Quick Start

```bash
# Single profile
sudo ./scripts/test-kvm-deploy.sh --profile matrix-minimal

# All 7 feature matrix profiles
sudo ./scripts/test-kvm-deploy.sh --profile all

# Keep VM alive for debugging
sudo ./scripts/test-kvm-deploy.sh --profile matrix-minimal --keep-vm
# Then: ssh -p 2222 root@localhost
```

## Prerequisites

- CachyOS rootfs at `/mnt/one/cachyos-root` (built by `bootstrap-cachyos.sh`)
- QEMU/KVM, edk2-ovmf, btrfs-progs, parted, rsync
- Root access (required for NBD mounts)

## How It Works

1. **Build**: Creates a qcow2 disk from the rootfs directory via NBD
   - Partitions (512M EFI + btrfs)
   - Creates btrfs subvolumes (@, @home, @cache, @log)
   - Rsyncs rootfs and Salt repo into the disk
   - Writes Salt grains (`host: profilename`) from feature_matrix.yaml
   - Installs Limine EFI bootloader

2. **Boot**: QEMU with KVM acceleration, virtio disk, user-mode networking
   - SSH forwarded to `localhost:2222`
   - Falls back to TCG emulation if `/dev/kvm` unavailable

3. **Deploy**: SSH into VM, runs `scripts/salt-apply.sh`
   - Salt installs if missing (`pacman -S salt`)
   - Output parsed for succeeded/failed/unchanged counts

4. **Health**: Runs `scripts/health-check.sh` (skip with `--no-health-check`)

5. **Report**: Summary to stdout + timestamped log file + optional JSON

## Key Flags

| Flag | Purpose |
|------|---------|
| `--profile NAME` | Profile from `states/data/feature_matrix.yaml` or `all` |
| `--keep-vm` | Don't destroy VM after test |
| `--fail-fast` | Stop on first failure |
| `--json` | Write JSON report file |
| `--timeout-boot 300` | Max seconds to wait for SSH |
| `--timeout-salt 900` | Max seconds for salt-apply |

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | All states succeeded, all services healthy |
| 1 | Salt errors or unhealthy services |
| 2 | Infrastructure error (rootfs missing, timeout, NBD failure) |
| 3 | Invalid arguments |

## Podman Wrapper

```bash
sudo ./scripts/vm-smoke.sh [/path/to/rootfs] [profile-name]
```

Runs the same test inside an `archlinux:latest` Podman container for CI/automation.

## Debugging

```bash
# Keep VM, SSH in, inspect
sudo ./scripts/test-kvm-deploy.sh --profile matrix-minimal --keep-vm
ssh -p 2222 root@localhost
# Salt output is in VM at /srv/salt
# Kill VM when done: kill $(cat /tmp/kvm-deploy-*/qemu.pid)

# Full log
cat logs/test-kvm-deploy-*.log
```
