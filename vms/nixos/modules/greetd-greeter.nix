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
    # GPU acceleration (virgl/virtio) — kernel module is in base.nix
    hardware.graphics = {
      enable = true;
      extraPackages = with pkgs; [ mesa ];
    };

    # Greeter wrapper: Hyprland + quickshell, fallback to agreety
    environment.etc."greetd/greeter-wrapper".source = pkgs.writeShellScript "greetd-greeter-wrapper" ''
      set -eu
      export HOME=${config.users.users.neg.home}
      export XDG_RUNTIME_DIR=/run/user/$(id -u neg)
      mkdir -p "$XDG_RUNTIME_DIR" 2>/dev/null || true
      chown neg:users "$XDG_RUNTIME_DIR" 2>/dev/null || true
      chmod 700 "$XDG_RUNTIME_DIR" 2>/dev/null || true
      export QT_QPA_PLATFORM=wayland
      export QT_WAYLAND_DISABLE_WINDOWDECORATION=1

      CRASH_FILE=/tmp/greetd-crash-count
      AGREETY=${pkgs.greetd}/bin/agreety
      HYPRLAND=${pkgs.hyprland}/bin/Hyprland
      QS=${pkgs.quickshell}/bin/qs
      GREETER_CONF=/etc/greetd/hyprland-greeter.conf
      GREETER_QML=$HOME/.config/quickshell/greeter/greeter.qml
      SESSION_WRAPPER=/etc/greetd/session-wrapper

      if [ -f "$CRASH_FILE" ] && [ $(($(date +%s) - $(stat -c %Y "$CRASH_FILE"))) -lt 30 ]; then
        count=$(cat "$CRASH_FILE")
      else
        count=0
      fi
      count=$((count + 1))
      echo "$count" > "$CRASH_FILE"

      if [ "$count" -ge 3 ]; then
        echo 0 > "$CRASH_FILE"
        exec "$AGREETY" --cmd "$SESSION_WRAPPER"
      fi

      if [ ! -e /dev/dri/card0 ] || [ ! -f "$GREETER_QML" ]; then
        exec "$AGREETY" --cmd "$SESSION_WRAPPER"
      fi

      exec "$HYPRLAND" --config "$GREETER_CONF"
    '';

    # Session wrapper: launches user's Hyprland
    environment.etc."greetd/session-wrapper".source = pkgs.writeShellScript "greetd-session-wrapper" ''
      set -eu
      export HOME="$1"
      shift
      exec ${pkgs.hyprland}/bin/Hyprland "$@"
    '';

    # Hyprland greeter config
    environment.etc."greetd/hyprland-greeter.conf".text = ''
      monitorv2 {
        output = Unknown-1; mode = preferred; position = 0x0; scale = 1
      }
      input { kb_layout = us,ru; kb_options = grp:alt_shift_toggle }
      cursor { no_hardware_cursors = true }
      misc { disable_hyprland_logo = true; force_default_wallpaper = 0; disable_autoreload = true }
      animations { enabled = false }
      decoration { blur { enabled = false }; shadow { enabled = false } }
      exec-once = qs -p ${config.users.users.neg.home}/.config/quickshell/greeter/greeter.qml
    '';

    # Greetd
    services.greetd = {
      enable = true;
      restart = true;
      settings.default_session = {
        command = "/etc/greetd/greeter-wrapper";
        user = "neg";
      };
    };

    # Auto-login (skips greeter, starts Hyprland directly)
    systemd.services."greetd-autologin" = lib.mkIf cfg.autoLogin {
      description = "Auto-login neg user into Hyprland";
      after = [ "greetd.service" "graphical.target" ];
      wantedBy = [ "graphical.target" ];
      serviceConfig = {
        Type = "simple";
        User = "neg";
        Environment = "XDG_RUNTIME_DIR=/run/user/1000";
      };
      script = ''
        sleep 5
        ${pkgs.hyprland}/bin/Hyprland
      '';
    };

    # Desktop portal
    xdg.portal = {
      enable = true;
      extraPortals = with pkgs; [
        xdg-desktop-portal-hyprland
        xdg-desktop-portal-gtk
      ];
      config.common.default = [ "hyprland" "gtk" ];
    };

    # Fonts
    fonts.packages = with pkgs; [
      jetbrains-mono nerd-fonts.jetbrains-mono nerd-fonts.symbols-only
      iosevka-neg-fonts noto-fonts-color-emoji dejavu_fonts liberation_ttf
    ];
    fonts.fontconfig = {
      enable = true;
      defaultFonts = {
        monospace = [ "JetBrains Mono" "IosevkaNeg" ];
        sansSerif = [ "Noto Sans" "DejaVu Sans" ];
        serif = [ "Noto Serif" "DejaVu Serif" ];
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

    # Qt theme
    qt = { enable = true; platformTheme = "gtk2"; style = "gtk2"; };

    environment.systemPackages = with pkgs; [ wiremix ];
  };
}
