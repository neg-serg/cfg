{
  description = "NixOS VM with Determinate Nix";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    determinate.url = "github:DeterminateSystems/determinate";
    determinate.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs = { self, nixpkgs, disko, determinate }: {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        determinate.nixosModules.default
        disko.nixosModules.disko
        ./disk-config.nix
        ({ pkgs, ... }: {
          system.stateVersion = "25.05";
          networking.hostName = "nixos";

          # SSH
          services.openssh.enable = true;
          services.openssh.settings.PasswordAuthentication = false;
          users.users.root.openssh.authorizedKeys.keys = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEx7F9KuTtPsLj9UVtUQ9ZrXUebjCMKuKZcyZWzg2RHf serg.zorg@gmail.com"
          ];
          users.users.nixos = {
            isNormalUser = true;
            extraGroups = [ "wheel" ];
            openssh.authorizedKeys.keys = [
              "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEx7F9KuTtPsLj9UVtUQ9ZrXUebjCMKuKZcyZWzg2RHf serg.zorg@gmail.com"
            ];
          };

          # Boot
          boot.loader.systemd-boot.enable = true;
          boot.initrd.availableKernelModules = [ "virtio_scsi" "virtio_blk" "virtio_net" "vfat" ];

          # Network
          systemd.network.enable = true;
          networking.useDHCP = true;

          # QEMU guest
          services.qemuGuest.enable = true;

          users.users.root.hashedPassword = "!";
        })
      ];
    };
  };
}
