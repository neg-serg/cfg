{ config, pkgs, lib, ... }:

let
  cfg = config._desktop;
in
{
  options._desktop = {
    autoLogin = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Auto-login neg user on boot (skips greeter for testing)";
    };
  };

  config = lib.mkIf cfg.enable {
    # GPU acceleration
    hardware.graphics = {
      enable = true;
      extraPackages = with pkgs; [ mesa ];
    };

    # Greetd
    services.greetd = {
      enable = true;
      restart = true;
      settings = {
        default_session = {
          command = "/etc/greetd/session-wrapper";
          user = "neg";
        };
      } // lib.optionalAttrs cfg.autoLogin {
        initial_session = {
          command = "${pkgs.hyprland}/bin/Hyprland";
          user = "neg";
        };
      };
    };

    # Session wrapper
    environment.etc."greetd/session-wrapper".source = pkgs.writeShellScript "greetd-session-wrapper" ''
      set -eu
      export HOME="$1"
      shift
      exec ${pkgs.hyprland}/bin/Hyprland "$@"
    '';

    # Minimal Hyprland config for VM
    environment.etc."greetd/hyprland-greeter.conf".text = ''
      monitor = Unknown-1, preferred, auto, 1
      input { kb_layout = us,ru; kb_options = grp:alt_shift_toggle }
      cursor { no_hardware_cursors = true }
      misc { disable_hyprland_logo = true; force_default_wallpaper = 0 }
      animations { enabled = false }
      decoration { blur { enabled = false }; shadow { enabled = false } }
      exec-once = ${pkgs.kitty}/bin/kitty
    '';

    # Desktop portal
    xdg.portal = {
      enable = true;
      extraPortals = with pkgs; [
        xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
      ];
      config.common.default = [ "hyprland" "gtk" ];
    };

    # Fonts
    fonts.packages = with pkgs; [
      jetbrains-mono nerd-fonts.jetbrains-mono nerd-fonts.symbols-only
      iosevka-neg-fonts noto-fonts-color-emoji
    ];
    fonts.fontconfig = {
      enable = true;
      defaultFonts = {
        monospace = [ "JetBrains Mono" ];
        sansSerif = [ "Noto Sans" ];
        serif = [ "Noto Serif" ];
      };
    };

    # Input
    i18n.inputMethod = {
      type = "fcitx5"; enable = true;
      fcitx5.addons = with pkgs; [ fcitx5-gtk fcitx5-mozc ];
    };

    # Services
    services.gnome.gnome-keyring.enable = true;
    services.gvfs.enable = true;
    services.upower.enable = true;
    powerManagement.enable = true;
    qt = { enable = true; platformTheme = "gtk2"; style = "gtk2"; };

    # Basic desktop packages (kitty terminal for the VM)
    environment.systemPackages = with pkgs; [
      kitty wiremix
    ];
  };
}
