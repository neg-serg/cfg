{ config, pkgs, lib, ... }:
{
  imports = [
    ./base.nix
  ];

  networking.hostName = lib.mkForce "telfir";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot";

  boot.kernelParams = lib.mkForce [ "console=tty0" ];
  boot.initrd.availableKernelModules = lib.mkForce [
    "nvme" "xhci_pci" "ahci" "usbhid" "sd_mod"
  ];
  boot.kernelModules = [ "amdgpu" ];
  # crc32c is a softdep of btrfs — must be in initrd for root mount
  boot.initrd.kernelModules = [ "amdgpu" "crc32c" "btrfs" "dm_mod" "xfs" ];

  services.qemuGuest.enable = lib.mkForce false;

  hardware.graphics.enable = true;

  hardware.cpu.amd.updateMicrocode = true;

  # Swapfiles on btrfs cause kernel panic (autofs). Disable for bare metal.
  swapDevices = lib.mkForce [ ];

  # Hugepages allocation can fail on systems with <32GB RAM
  boot.kernel.sysctl."vm.nr_hugepages" = lib.mkForce 0;

  nix.settings = lib.mkForce {
    max-jobs = 16;
    cores = 16;
    substituters = [ "https://cache.nixos.org" "https://hyprland.cachix.org" ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
    ];
  };
}
