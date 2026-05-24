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

    # Greetd (disabled when autoLogin, only for fallback greeter)
    services.greetd = lib.mkIf (!cfg.autoLogin) {
      enable = true;
      restart = true;
      settings = {
        default_session = {
          command = "/etc/greetd/session-wrapper";
          user = "neg";
        };
      };
    };

    # Auto-login: Hyprland as system service on tty1
    systemd.services.hyprland-autologin = lib.mkIf cfg.autoLogin {
      description = "Hyprland compositor (auto-login)";
      after = [ "systemd-user-sessions.service" "user-runtime-dir@1000.service" ];
      wants = [ "user-runtime-dir@1000.service" "dev-dri-device\x2dcard0.device" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        User = "neg";
        Group = "users";
        ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p /run/user/1000";
        ExecStart = "${pkgs.hyprland}/bin/Hyprland";
        Environment = [
          "XDG_RUNTIME_DIR=/run/user/1000"
          "WLR_NO_HARDWARE_CURSORS=1"
          "WLR_RENDERER_ALLOW_SOFTWARE=1"
          "XDG_SESSION_TYPE=wayland"
          "DISPLAY="
        ];
      };
    };

    # Session wrapper
    environment.etc."greetd/session-wrapper".source = pkgs.writeShellScript "greetd-session-wrapper" ''
      set -eu
      export HOME="$1"
      shift
      exec ${pkgs.hyprland}/bin/Hyprland "$@"
    '';

    # Minimal Hyprland config for VM (avoids custom dotfiles issues)
    environment.etc."hypr/hyprland.conf".source = pkgs.writeText "hyprland-vm.conf" ''
      monitor = , preferred, auto, 1
      input { kb_layout = us,ru; kb_options = grp:alt_shift_toggle }
      cursor { no_hardware_cursors = true }
      misc { disable_hyprland_logo = true; force_default_wallpaper = 0 }
      animations { enabled = false }
      decoration { blur { enabled = false }; shadow { enabled = false } }
      exec-once = kitty
    '';

    # Symlink VM config to user home
    systemd.tmpfiles.rules = [
      "L+ /home/neg/.config/hypr/hyprland.conf - - - - /etc/hypr/hyprland.conf"
    ];

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
      kitty wiremix vulkan-loader vulkan-tools mesa
    ];
  };
}
