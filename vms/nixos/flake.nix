{
  description = "NixOS VM with Determinate Nix — full workstation equivalent to Salt config";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    ragenix.url = "github:yaxitech/ragenix";
    ragenix.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs = { self, nixpkgs, disko, ragenix }: let
    specialArgs = {
      ageKeyPath = builtins.getEnv "AGE_KEY_PATH" or "/run/secrets/age-key.txt";
      proxyHost = builtins.getEnv "PROXY_HOST" or "";
      proxyPort = builtins.getEnv "PROXY_PORT" or "10808";
    };
  in {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = specialArgs // { inherit ragenix; };
      modules = [
        disko.nixosModules.disko
        ./disk-config.nix
        ragenix.nixosModules.age
        ./age.secrets.nix

        ./modules/defaults.nix
        ./modules/base.nix
        ./modules/packages.nix
        ./modules/desktop.nix
        ./modules/audio.nix
        ./modules/network.nix
        ./modules/containers.nix
        ./modules/ai.nix
        ./modules/monitoring.nix
        ./modules/steam.nix
        ./modules/dev.nix
        ./modules/proxy.nix

        ./pkgs/default.nix
      ];
    };
  };
}
