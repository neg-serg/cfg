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

    # Greetd display manager with Hyprland session
    services.greetd = {
      enable = true;
      settings = {
        default_session = {
          command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd Hyprland";
          user = "greeter";
        };
      };
    };

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
      noto-fonts-cjk
      jetbrains-mono
      nerd-fonts.jetbrains-mono
      nerd-fonts.symbols-only
      iosevka-neg-fonts  # custom
      noto-fonts-emoji
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

    # Kanata keyboard remapper
    services.kanata = {
      enable = true;
      keyboards.main = {
        config = ''
          (defsrc)
          (deflayer base)
        '';
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
