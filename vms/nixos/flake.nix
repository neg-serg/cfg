{
  description = "NixOS — experimental (VM + bare metal)";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };
  outputs = { self, nixpkgs }: {

    # ── VM (QEMU/KVM) ───────────────────────────────────
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./modules/base.nix
        ./modules/zsh.nix
        ./modules/packages.nix
        ./modules/network.nix
        ./pkgs/default.nix
        { nixpkgs.config.doCheckByDefault = false; }
        ({ ... }: {
          fileSystems."/" = {
            device = "/dev/sda2";
            fsType = "ext4";
          };
          fileSystems."/boot" = {
            device = "/dev/sda1";
            fsType = "vfat";
          };
        })
      ];
    };

    # ── Bare metal (dual-boot with CachyOS) ────────────
    nixosConfigurations.telfir = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./modules/bare-metal.nix
        ./modules/zsh.nix
        ./modules/packages.nix
        ./modules/network.nix
        ./pkgs/default.nix
        { nixpkgs.config.doCheckByDefault = false; }
        ({ ... }: {
          fileSystems."/" = {
            device = "/dev/nvme0n1p2";
            fsType = "btrfs";
          };
          fileSystems."/boot" = {
            device = "/dev/nvme0n1p5";
            fsType = "vfat";
          };
        })
      ];
    };

  };
}
