{ config, pkgs, lib, ... }:

{
  imports = [];

  system.stateVersion = "25.05";
  networking.hostName = "nixos";

  # Users
  users.users.root = {
    hashedPassword = "!";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEx7F9KuTtPsLj9UVtUQ9ZrXUebjCMKuKZcyZWzg2RHf serg.zorg@gmail.com"
    ];
  };

  users.users.nixos = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEx7F9KuTtPsLj9UVtUQ9ZrXUebjCMKuKZcyZWzg2RHf serg.zorg@gmail.com"
    ];
  };

  # Locale
  i18n.defaultLocale = "en_US.UTF-8";
  time.timeZone = "Europe/Moscow";

  # SSH
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
  };

  # Boot
  boot.loader.systemd-boot.enable = true;
  boot.initrd.availableKernelModules = [
    "virtio_scsi" "virtio_blk" "virtio_net" "vfat"
  ];

  # Network (uses networkd with DHCP)
  systemd.network.enable = true;
  networking.useNetworkd = true;

  # QEMU guest agent
  services.qemuGuest.enable = true;

  # Nix settings — Determinate Nix cache
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    substituters = [ "https://install.determinate.systems" ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "install.determinate.systems:2/bvnFWPrR6uxEXpB7XqOSykYemH8e8WoMWvoLLXpF4="
    ];
    http-connections = 25;
    accept-flake-config = true;
  };

  # Persist flake config to /etc/nixos
  environment.etc."nixos/flake.nix".source = ../flake.nix;
  environment.etc."nixos/disk-config.nix".source = ../disk-config.nix;
}
