{ config, pkgs, lib, ... }:

let
  cfg = config._desktop;
in
{
  options._desktop.enable = lib.mkEnableOption "Desktop environment (Hyprland, greetd, fonts, themes)";

  config = lib.mkIf cfg.enable {

    # Hyprland Wayland compositor
    programs.hyprland = {
      enable = true;
      withUWSM = true;
    };

    # Niri scrolling-tiling compositor (secondary option)
    # programs.niri.enable = true;

    # Greetd display manager (configured in greetd-greeter.nix)
    # services.greetd — see modules/greetd-greeter.nix

    # XDG Desktop Portal
    xdg.portal = {
      enable = true;
      extraPortals = with pkgs; [
        xdg-desktop-portal-hyprland
        xdg-desktop-portal-gtk
      ];
      config.common.default = [ "hyprland" "gtk" ];
    };

    # Fonts (from data/fonts.yaml + additional)
    fonts.packages = with pkgs; [
      jetbrains-mono
      nerd-fonts.jetbrains-mono
      nerd-fonts.symbols-only
      iosevka-neg-fonts
      noto-fonts-color-emoji
      dejavu_fonts
      liberation_ttf
    ];

    # Font config
    fonts.fontconfig = {
      enable = true;
      defaultFonts = {
        monospace = [ "JetBrains Mono" "IosevkaNeg" ];
        sansSerif = [ "Noto Sans" "DejaVu Sans" ];
        serif = [ "Noto Serif" "DejaVu Serif" ];
      };
    };

    # Input methods
    i18n.inputMethod = {
      type = "fcitx5";
      enable = true;
      fcitx5.addons = with pkgs; [ fcitx5-gtk fcitx5-mozc ];
    };

    # Desktop portal backends
    services.gnome.gnome-keyring.enable = true;
    services.gvfs.enable = true;

    # Power management
    services.upower.enable = true;
    powerManagement.enable = true;

    # Qt/KDE theme integration
    qt = {
      enable = true;
      platformTheme = "gtk2";
      style = "gtk2";
    };

    # Kanata keyboard remapper — manual service (nixpkgs module broken)
    systemd.user.services.kanata = {
      description = "Kanata keyboard remapper";
      after = [ "graphical-session.target" ];
      wantedBy = [ "default.target" ];
      partOf = [ "graphical-session.target" ];
      serviceConfig = {
        Type = "simple";
        Restart = "on-failure";
        RestartSec = 5;
        ExecStart = "${pkgs.kanata}/bin/kanata --cfg %h/.config/kanata/config.kdb";
      };
    };

    # Espanso text expander
    services.espanso = {
      enable = true;
    };

    # Wiremix audio visualizer
    environment.systemPackages = with pkgs; [
      wiremix
    ];
  };
}
