#!/bin/bash
# Append NixOS generation entries to limine.cfg on ESP.
# Called by Salt state (onchanges) or manually from CachyOS side.
set -euo pipefail

NIXOS_PARTUUID="4d2585cf-07cf-4ad8-aa52-3c62d780cd03"
NIXOS_FS_UUID="10d42115-ab09-4142-bb50-9ec56fcda509"
MNT="/tmp/limine-nixos-mnt"
CONFIG="/efi/EFI/Limine/limine.cfg"
MARKER="# @nixos-generations"
MAX_GENS=5

cleanup() { mountpoint -q "$MNT" 2>/dev/null && sudo umount "$MNT" 2>/dev/null || true; rmdir "$MNT" 2>/dev/null || true; }
trap cleanup EXIT

mkdir -p "$MNT"
sudo mount -o ro "PARTUUID=${NIXOS_PARTUUID}" "$MNT" 2>/dev/null || {
    echo "limine-generations: NixOS partition not found, skipping" >&2
    exit 0
}

PROFILES_DIR="$MNT/nix/var/nix/profiles"
[ -d "$PROFILES_DIR" ] || { echo "limine-generations: no NixOS profiles dir" >&2; exit 0; }

# Strip existing NixOS entries
sudo sed -i "/^${MARKER}/,\$d" "$CONFIG" 2>/dev/null

# Write marker header
{
    echo ""
    echo "# --- NixOS generations (auto-generated) ---"
    echo "$MARKER"
    echo ""
} | sudo tee -a "$CONFIG" > /dev/null

count=0
while IFS= read -r profile_link; do
    [ $count -ge $MAX_GENS ] && break
    # Resolve symlink to get the generation's boot.json
    boot_json="$profile_link/boot.json"
    [ -f "$boot_json" ] || continue

    label=$(jq -r '.["org.nixos.bootspec.v1"].label // "NixOS"' "$boot_json")
    kernel=$(jq -r '.["org.nixos.bootspec.v1"].kernel' "$boot_json")
    initrd=$(jq -r '.["org.nixos.bootspec.v1"].initrd' "$boot_json")
    init=$(jq -r '.["org.nixos.bootspec.v1"].init' "$boot_json")
    params=$(jq -r '.["org.nixos.bootspec.v1"].kernelParams | join(" ")' "$boot_json")

    [ -n "$kernel" ] && [ -n "$initrd" ] || continue

    gen_num=$(basename "$profile_link" | sed -E 's/system-([0-9]+)-link/\1/')
    [ "$gen_num" = "$(basename "$profile_link")" ] && gen_num="?"

    sudo tee -a "$CONFIG" > /dev/null <<ENTRY
:NixOS (Generation ${gen_num} — ${label})
    PROTOCOL=linux
    COMMENT=NixOS ${label}
    KERNEL_CMDLINE=root=PARTUUID=${NIXOS_PARTUUID} rw init=${init} ${params}
    KERNEL_PATH=uuid(${NIXOS_FS_UUID})://${kernel#/}
    MODULE_PATH=uuid(${NIXOS_FS_UUID})://${initrd#/}

ENTRY
    count=$((count + 1))
done < <(find "$PROFILES_DIR" -maxdepth 1 -name 'system-*-link' -type l | sort -r)

echo "limine-generations: appended $count NixOS generation(s)"
