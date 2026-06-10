{
  description = "NixOS VM — experimental";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };
  outputs = { self, nixpkgs }: {
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
  };
}
