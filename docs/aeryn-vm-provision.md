# AerynOS VM Provisioning Guide

Self-contained LLM prompt for provisioning the `aerynos-gnome` VM from scratch.

## Prerequisites

- CachyOS host with libvirt + qemu + OVMF
- ISO at `/mnt/one/vms/AerynOS-GNOME-live-x86_64.iso` (AerynOS 2026.05)
- Target disk at `/mnt/one/vms/aerynos-gnome.qcow2`
- Host NBD kernel module available (`modprobe nbd`)

## Disk Layout

| Partition | Size | Type | Purpose |
|-----------|------|------|---------|
| vda1 | 8 GiB | EFI System (type 1) | /boot |
| vda2 | rest | Linux filesystem (type 20) | / |

## Step 1: Create Disk

```bash
sudo qemu-img create -f qcow2 /mnt/one/vms/aerynos-gnome.qcow2 120G
sudo qemu-nbd --connect=/dev/nbd0 /mnt/one/vms/aerynos-gnome.qcow2
echo -e "g\nn\n1\n\n+8G\nt\n1\nn\n2\n\n\nw\n" | sudo fdisk /dev/nbd0
sudo mkfs.fat -F32 /dev/nbd0p1
sudo mkfs.ext4 -F /dev/nbd0p2
sudo qemu-nbd --disconnect /dev/nbd0
```

## Step 2: Define VM

Create domain XML at `vms/aerynos-gnome.xml` with these critical settings:

```xml
<domain type='kvm'>
  <name>aerynos-gnome</name>
  <memory unit='KiB'>16777216</memory>
  <vcpu placement='static'>24</vcpu>
  <os firmware='efi'>
    <type arch='x86_64' machine='pc-q35-11.0'>hvm</type>
    <firmware>
      <feature enabled='no' name='enrolled-keys'/>
      <feature enabled='no' name='secure-boot'/>
    </firmware>
    <loader readonly='yes' type='pflash' format='raw'>/usr/share/edk2/x64/OVMF_CODE.4m.fd</loader>
    <nvram template='/usr/share/edk2/x64/OVMF_VARS.4m.fd' templateFormat='raw' format='raw'>/var/lib/libvirt/qemu/nvram/aerynos-gnome_VARS.fd</nvram>
    <boot dev='cdrom'/>
    <boot dev='hd'/>
  </os>
  <cpu mode='host-passthrough' check='none' migratable='on'>
    <topology sockets='1' dies='1' cores='24' threads='1'/>
  </cpu>
  <devices>
    <disk type='file' device='disk'>
      <driver name='qemu' type='qcow2' cache='writeback' io='threads'/>
      <source file='/mnt/one/vms/aerynos-gnome.qcow2'/>
      <target dev='vda' bus='virtio'/>
    </disk>
    <disk type='file' device='cdrom'>
      <driver name='qemu' type='raw'/>
      <source file='/mnt/one/vms/AerynOS-GNOME-live-x86_64.iso'/>
      <target dev='sda' bus='sata'/>   <!-- MUST be sata, not scsi -->
      <readonly/>
    </disk>
    <interface type='network'>
      <mac address='52:54:00:aa:80:3c'/>   <!-- FIXED MAC for consistent IP -->
      <source network='default'/>
      <model type='virtio'/>
    </interface>
    <channel type='unix'>
      <target type='virtio' name='org.qemu.guest_agent.0'/>
    </channel>
    <controller type='virtio-serial' index='0'/>
    <graphics type='vnc' port='5901' autoport='no' listen='127.0.0.1'/>
    <video><model type='virtio' heads='1' primary='yes'/></video>
    <tpm model='tpm-crb'><backend type='emulator' version='2.0'/></tpm>
    <rng model='virtio'><backend model='random'>/dev/urandom</backend></rng>
    <memballoon model='none'/>
  </devices>
</domain>
```

Key XML notes:
- **`boot dev='cdrom'` first**: boots ISO to perform installation
- **CDROM bus MUST be `sata`**: OVMF won't boot from `scsi` bus
- **`OVMF_CODE.4m.fd`**: non-secure-boot firmware (avoids signing issues)
- **Fixed MAC**: prevents IP changes on domain redefinition

Define and start:
```bash
sudo virsh define vms/aerynos-gnome.xml
sudo virsh start aerynos-gnome
```

## Step 3: Base System Install (via QEMU guest agent)

Wait for ISO boot (~40s), then use `guest-exec`:

```bash
# Verify agent is up
sudo virsh qemu-agent-command aerynos-gnome '{"execute":"guest-ping"}'

# Mount target, configure repo, install base system
sudo virsh qemu-agent-command aerynos-gnome '{"execute":"guest-exec", "arguments":{"path":"/bin/sh", "arg":["-c",
  "mkdir -p /mnt/boot && mount /dev/vda2 /mnt && mount /dev/vda1 /mnt/boot && "
  "moss -D /mnt repo add volatile https://build.aerynos.dev/stream/volatile/x86_64/stone.index && "
  "moss -D /mnt install -y linux-desktop linux-firmware pkgset-aeryn-base pkgset-aeryn-base-desktop gnome-desktop gnome-desktop-defaults sed grep gawk dracut openssh-server 2>&1 | tail -5"
], "capture-output":true}}'
```

Wait for moss install to complete (may take 2-5 minutes).

## Step 4: Post-Install Configuration

Mount proc/sys/dev and chroot to configure the system:

```bash
# Mount everything needed for chroot
sudo virsh qemu-agent-command aerynos-gnome '{"execute":"guest-exec", "arguments":{"path":"/bin/sh", "arg":["-c",
  "mount -t proc proc /mnt/proc && mount -t sysfs sys /mnt/sys && "
  "mount --bind /dev /mnt/dev && mkdir -p /mnt/var/cache/ldconfig && "
  "mount -t efivarfs efivarfs /mnt/sys/firmware/efi/efivars 2>/dev/null; "
  "echo 'READY'"
], "capture-output":true}}'
```

### 4a. Create /etc/fstab

```bash
# Get PARTUUIDs first
sudo fdisk -l /dev/vda  # or check with: blkid /dev/vda1 /dev/vda2
```

Then write fstab:
```
/dev/vda2 / ext4 defaults 0 1
/dev/vda1 /boot vfat defaults 0 2
```

Via guest-exec:
```bash
sudo virsh qemu-agent-command aerynos-gnome '{"execute":"guest-exec", "arguments":{"path":"/bin/sh", "arg":["-c",
  "echo '/dev/vda2 / ext4 defaults 0 1\n/dev/vda1 /boot vfat defaults 0 2' > /mnt/etc/fstab"
], "capture-output":true}}'
```

### 4b. Set root password

```bash
sudo virsh qemu-agent-command aerynos-gnome '{"execute":"guest-exec", "arguments":{"path":"/bin/sh", "arg":["-c",
  "printf 'neg\\nneg\\n' | chroot /mnt passwd root"
], "capture-output":true}}'
```

### 4c. Enable services

```bash
sudo virsh qemu-agent-command aerynos-gnome '{"execute":"guest-exec", "arguments":{"path":"/bin/sh", "arg":["-c",
  "ln -sf /usr/lib/systemd/system/gdm.service /mnt/etc/systemd/system/display-manager.service && "
  "ln -sf /usr/lib/systemd/system/graphical.target /mnt/etc/systemd/system/default.target && "
  "chroot /mnt systemctl enable NetworkManager sshd 2>&1"
], "capture-output":true}}'
```

### 4d. Rebuild initrd with virtio drivers

```bash
sudo virsh qemu-agent-command aerynos-gnome '{"execute":"guest-exec", "arguments":{"path":"/bin/sh", "arg":["-c",
  "chroot /mnt ldconfig 2>/dev/null; "
  "chroot /mnt dracut --force --kver $(ls /mnt/usr/lib/modules/ | head -1) "
  "--add-drivers 'virtio_blk virtio_pci virtio_net virtio_scsi ext4 vfat' 2>&1 | tail -5; "
  "cp /mnt/boot/initramfs-*.img /mnt/boot/initrd-working.img"
], "capture-output":true}}'
```

### 4e. Run moss boot sync (creates EFI NVRAM entry!)

```bash
sudo virsh qemu-agent-command aerynos-gnome '{"execute":"guest-exec", "arguments":{"path":"/bin/sh", "arg":["-c",
  "chroot /mnt moss boot sync 2>&1; "
  "echo '---ENTRIES---'; cat /mnt/boot/loader/entries/*.conf"
], "capture-output":true}}'
```

### 4f. Verify boot config

```bash
sudo virsh qemu-agent-command aerynos-gnome '{"execute":"guest-exec", "arguments":{"path":"/bin/sh", "arg":["-c",
  "echo '=== ESP ==='; df -h /mnt/boot; "
  "echo '=== entries ==='; ls /mnt/boot/loader/entries/; "
  "echo '=== EFI ==='; find /mnt/boot/EFI -type f | sort"
], "capture-output":true}}'
```

## Step 5: Reboot

```bash
# Detach ISO
sudo virsh detach-disk aerynos-gnome sda --config

# Rebooting WITHOUT redefine preserves NVRAM:
sudo virsh destroy aerynos-gnome
sudo virsh start aerynos-gnome
```

Wait ~30s for boot. Check DHCP lease for IP if MAC changed:
```bash
sudo virsh net-dhcp-leases default
```

SSH: `ssh root@<IP>`, password: `neg`

## Critical Pitfalls

1. **NVRAM resets on every `virsh define`**: After running `moss boot sync` from chroot (which writes to NVRAM), NEVER redefine the domain. Use `virsh destroy` + `virsh start` to reboot.

2. **CDROM bus MUST be `sata`**: OVMF cannot boot from `scsi` bus CDROM. The error is silent — guest agent never responds.

3. **Mount `efivarfs` in chroot before `moss boot sync`**: Without it, moss can't write the EFI boot entry to NVRAM.

4. **Initrd must include virtio drivers**: Use `--add-drivers "virtio_blk virtio_pci virtio_net virtio_scsi ext4 vfat"` with dracut. Without these, the kernel can't find the root filesystem.

5. **dracut needs tools in chroot**: `sed`, `grep`, `gawk`, `ldconfig` must be installed. Proc/sys/dev must be mounted.

6. **Secure boot firmware** (`OVMF_CODE.secboot.4m.fd`): Avoid it unless you explicitly sign the bootloader. Use `OVMF_CODE.4m.fd` instead.

7. **ESP sizing**: 8G recommended. 512M will fill up quickly with kernel updates (moss creates multiple initrd snapshots).

8. **MAC address**: Every `virsh define` generates a new MAC unless explicitly set in XML. Use a fixed MAC to keep a stable IP.

## Recovery: re-establish EFI boot after accidental NVRAM loss

If the VM boots to UEFI shell (NVRAM was reset):
1. Attach ISO, set cdrom first in boot order
2. Boot ISO, connect via guest agent
3. Mount root+ESP, mount proc/sys/dev/efivarfs
4. `chroot /mnt moss boot sync`
5. Detach ISO, `virsh destroy` + `virsh start` (NEVER `virsh define`)
