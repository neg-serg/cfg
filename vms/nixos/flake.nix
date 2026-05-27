{
  description = "NixOS VM — minimal boot test";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    ambxst.url = "github:Axenide/Ambxst";
    ambxst.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs = { self, nixpkgs, disko, ambxst }: {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./pkgs/default.nix
        ./disk-config.nix
        ambxst.nixosModules.default

        ({ pkgs, ... }: {
          system.stateVersion = "25.05";
          networking.hostName = "nixos";
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
          environment.systemPackages = with pkgs; [ git vim tmux ];
          programs.ambxst.enable = true;
        })

        ./modules/defaults.nix
        ./modules/base.nix
        ./modules/zsh.nix
        ./modules/packages.nix
        ./modules/network.nix
      ];
    };
  };
}
