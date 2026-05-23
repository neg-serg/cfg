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
    envDefault = name: default:
      let v = builtins.getEnv name; in if v == "" then default else v;
    specialArgs = {
      ageKeyPath = envDefault "AGE_KEY_PATH" "/run/secrets/age-key.txt";
      proxyHost = envDefault "PROXY_HOST" "";
      proxyPort = envDefault "PROXY_PORT" "10808";
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
        ./modules/zsh.nix
        ./modules/greetd-greeter.nix
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
