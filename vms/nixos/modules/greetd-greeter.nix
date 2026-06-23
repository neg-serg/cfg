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
    # Boot into graphical.target (required for greetd)
    systemd.defaultUnit = "graphical.target";

    hardware.graphics = {
      enable = true;
      extraPackages = with pkgs; [ mesa ];
    };

    # ── Wrappers (match CachyOS: greeter-wrapper → agreety → session-wrapper → Hyprland) ──

    # Session wrapper — full desktop after login
    environment.etc."greetd/session-wrapper".source = pkgs.writeShellScript "greetd-session-wrapper" ''
      [ -f /etc/profile ] && . /etc/profile
      set -a
      [ -f "$HOME/.config/environment.d/10-user.conf" ] && . "$HOME/.config/environment.d/10-user.conf"
      set +a
      export QT_QPA_PLATFORM=wayland
      export XDG_SESSION_TYPE=wayland
      exec ${pkgs.hyprland}/bin/Hyprland
    '';

    # Greeter wrapper — shows login screen (agreety), then calls session-wrapper
    environment.etc."greetd/greeter-wrapper".source = pkgs.writeShellScript "greetd-greeter-wrapper" ''
      set -eu
      export HOME=/home/neg
      set +eu
      [ -f /etc/profile ] && . /etc/profile
      [ -f "$HOME/.config/environment.d/10-user.conf" ] && . "$HOME/.config/environment.d/10-user.conf"
      set -eu
      export QT_QPA_PLATFORM=wayland
      exec ${pkgs.greetd}/bin/agreety --cmd /etc/greetd/session-wrapper
    '';

    # ── Greetd ──

    services.greetd = lib.mkIf (!cfg.autoLogin) {
      enable = true;
      restart = true;
      settings = {
        default_session = {
          command = "/etc/greetd/greeter-wrapper";
          user = "neg";
        };
      };
    };

    # Auto-login fallback
    systemd.services.hyprland-autologin = lib.mkIf cfg.autoLogin {
      description = "Hyprland compositor (auto-login)";
      after = [ "systemd-user-sessions.service" "user-runtime-dir@1000.service" ];
      wants = [ "user-runtime-dir@1000.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        User = "neg";
        ExecStart = "/etc/greetd/session-wrapper";
      };
    };

    # ── Hyprland configs ──

    # Base fallback config (used before chezmoi applies)
    environment.etc."hypr/hyprland-base.conf".source = pkgs.writeText "hyprland-base.conf" ''
      monitor = , preferred, auto, 1
      input { kb_layout = us,ru; kb_options = grp:alt_shift_toggle }
      misc { disable_hyprland_logo = true }
      exec-once = kitty
    '';

    systemd.tmpfiles.rules = [
      "L+ /home/neg/.config/hypr/hyprland.conf - - - - /etc/hypr/hyprland-base.conf"
    ];

    # ── Portals, fonts, input, services ──

    xdg.portal = {
      enable = true;
      extraPortals = with pkgs; [
        xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
      ];
      config.common.default = [ "hyprland" "gtk" ];
    };

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

    i18n.inputMethod = {
      type = "fcitx5"; enable = true;
      fcitx5.addons = with pkgs; [ fcitx5-gtk fcitx5-mozc ];
    };

    services.gnome.gnome-keyring.enable = true;
    services.gvfs.enable = true;
    services.upower.enable = true;
    powerManagement.enable = true;
    qt = { enable = true; platformTheme = "gtk2"; style = "gtk2"; };

    environment.systemPackages = with pkgs; [
      kitty wiremix vulkan-loader vulkan-tools mesa
    ];
  };
}
