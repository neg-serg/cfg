{ config, pkgs, lib, ... }:
{
  imports = [
    ./base.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot";

  boot.kernelParams = lib.mkForce [ "quiet" ];
  boot.initrd.availableKernelModules = lib.mkForce [
    "nvme" "xhci_pci" "ahci" "usbhid" "sd_mod"
  ];
  boot.kernelModules = [ "amdgpu" ];
  boot.initrd.kernelModules = [ "amdgpu" ];

  services.qemuGuest.enable = lib.mkForce false;

  hardware.opengl.enable = true;

  hardware.cpu.amd.updateMicrocode = true;

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
