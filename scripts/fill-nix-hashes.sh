#!/bin/bash
# Fill remaining NixOS overlay hashes by building and capturing expected values.
# Run this INSIDE the NixOS VM or on a host with nix installed.
set -euo pipefail
CFG=/home/neg/src/cfg

echo "=== Step 1: Build all overlays, capture fetchurl hashes ==="
cd "$CFG"

# Packages with empty or placeholder hashes to fill:
MISSING=(
  "vms/nixos/pkgs/aliae-bin.nix"
  "vms/nixos/pkgs/antigravity-tools-bin.nix"
  "vms/nixos/pkgs/bottles.nix"
  "vms/nixos/pkgs/cloudflare-speed-cli.nix"
  "vms/nixos/pkgs/eilmeldung-bin.nix"
  "vms/nixos/pkgs/flclashx-bin.nix"
  "vms/nixos/pkgs/gitlogue.nix"
  "vms/nixos/pkgs/goverlay.nix"
  "vms/nixos/pkgs/grex.nix"
  "vms/nixos/pkgs/hxd-bin.nix"
  "vms/nixos/pkgs/hyprquickframe.nix"
  "vms/nixos/pkgs/hyprscratch.nix"
  "vms/nixos/pkgs/instagram-cli.nix"
  "vms/nixos/pkgs/lazytail-bin.nix"
  "vms/nixos/pkgs/neo-matrix-bin.nix"
  "vms/nixos/pkgs/no-more-secrets.nix"
  "vms/nixos/pkgs/opencode.nix"
  "vms/nixos/pkgs/opensoundmeter.nix"
  "vms/nixos/pkgs/oports-git.nix"
  "vms/nixos/pkgs/otter-launcher.nix"
  "vms/nixos/pkgs/oyo.nix"
  "vms/nixos/pkgs/pipemixer.nix"
  "vms/nixos/pkgs/protonup-rs.nix"
  "vms/nixos/pkgs/qman.nix"
  "vms/nixos/pkgs/rofi-file-browser-extended.nix"
  "vms/nixos/pkgs/strace-tui.nix"
  "vms/nixos/pkgs/tdl-bin.nix"
  "vms/nixos/pkgs/yandex-browser-bin.nix"
)

for f in "${MISSING[@]}"; do
  echo ""
  echo "--- $f ---"
  # Try to build, capture expected hash from error
  nix-build -E "with import <nixpkgs> {}; callPackage $CFG/$f {}" 2>&1 | \
    grep -E '(got:|hash:|expected:|sha256-)' || true
done

echo ""
echo "=== Step 2: For buildGoModule packages, set vendorHash = \"\"; then: ==="
echo "  nix-build ... 2>&1 | grep 'got:'"
echo "  # Copy the hash from 'got: sha256-...' into vendorHash"
echo ""
echo "=== Done! ==="
