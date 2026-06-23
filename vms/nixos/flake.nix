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
        ./modules/bare-metal.nix       # imports base.nix, overrides for bare metal
        ./modules/desktop.nix
        ./modules/audio.nix
        ./modules/dev.nix
        ./modules/steam.nix
        ./modules/containers.nix
        ./modules/user-services.nix
        ./modules/flatpak.nix
        ./modules/greetd-greeter.nix
        ./modules/mpd.nix
        ./modules/monitoring.nix
        ./modules/espanso.nix
        ./modules/ai.nix
        ./modules/proxy.nix
        ./modules/proxypilot-service.nix
        ./modules/installers.nix
        ./modules/defaults.nix
        ./modules/duckdns.nix
        ./modules/opencode.nix
        ./modules/zen-profiles.nix
        ./modules/filesystems.nix
        ./modules/system-tuning.nix
        ./modules/zsh.nix
        ./modules/packages.nix
        ./modules/network.nix
        ./pkgs/default.nix
        { nixpkgs.config.doCheckByDefault = false; }
        ({ config, lib, ... }: {
          nixpkgs.overlays = [
            (final: prev: {
              pipx = prev.pipx.overridePythonAttrs (_: { doCheck = false; });
            })
          ];
          fileSystems."/" = {
            device = "/dev/nvme0n1p2";
            fsType = "btrfs";
          };
          fileSystems."/boot" = {
            device = "/dev/nvme0n1p5";
            fsType = "vfat";
          };
          # Enable all feature modules
          _desktop.enable = lib.mkDefault true;
          _desktop.autoLogin = lib.mkDefault true;  # skip greetd greeter
          _audio.enable = lib.mkDefault true;
          _dev.enable = lib.mkDefault true;
          _steam.enable = lib.mkDefault true;
          _containers.enable = lib.mkDefault true;
          _userServices.enable = lib.mkDefault true;
          _flatpak.enable = lib.mkDefault true;
          _mpd.enable = lib.mkDefault true;
          _monitoring.enable = lib.mkDefault true;
          _espanso.enable = lib.mkDefault true;
          _ai.enable = lib.mkDefault true;
          _proxy.enable = lib.mkDefault false;  # requires proxyHost config
          _proxypilot.enable = lib.mkDefault true;
          _installers.enable = lib.mkDefault true;
          _duckdns.enable = lib.mkDefault true;
          _opencode.enable = lib.mkDefault true;
          _zenProfiles.enable = lib.mkDefault true;
          _filesystems.enable = lib.mkDefault true;
          _systemTuning.enable = lib.mkDefault true;
          # Proxy module requires proxyHost arg
          _module.args.proxyHost = "";
          _module.args.proxyPort = "10808";
        })
      ];
    };

  };
}
