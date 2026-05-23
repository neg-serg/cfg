{ config, pkgs, lib, ... }:

let
  cfg = config._desktop;
in
{
  config = lib.mkIf cfg.enable {
    # GPU acceleration (virgl/virtio) — kernel module is in base.nix
    hardware.graphics = {
      enable = true;
      extraPackages = with pkgs; [ mesa ];
    };

    # Hyprland greeter config — minimal for VM (no monitor-specific settings)
    environment.etc."greetd/hyprland-greeter.conf".text = ''
      monitorv2 {
        output = Unknown-1
        mode = preferred
        position = 0x0
        scale = 1
      }

      input {
        kb_layout = us,ru
        kb_options = grp:alt_shift_toggle
      }

      cursor {
        no_hardware_cursors = true
      }

      misc {
        disable_hyprland_logo = true
        force_default_wallpaper = 0
        disable_autoreload = true
      }

      animations {
        enabled = false
      }

      decoration {
        blur { enabled = false }
        shadow { enabled = false }
      }

      exec-once = qs -p ${config.users.users.neg.home}/.config/quickshell/greeter/greeter.qml
    '';

    # Greeter wrapper: Hyprland + quickshell, fallback to agreety
    environment.etc."greetd/greeter-wrapper".source = pkgs.writeShellScript "greetd-greeter-wrapper" ''
      set -eu
      export HOME=${config.users.users.neg.home}
      export XDG_RUNTIME_DIR=/run/user/$(id -u neg)
      export QT_QPA_PLATFORM=wayland
      export QT_WAYLAND_DISABLE_WINDOWDECORATION=1

      CRASH_FILE=/tmp/greetd-crash-count
      AGREETY=${pkgs.greetd}/bin/agreety
      HYPRLAND=${pkgs.hyprland}/bin/Hyprland
      QS=${pkgs.quickshell}/bin/qs
      GREETER_CONF=/etc/greetd/hyprland-greeter.conf
      GREETER_QML=$HOME/.config/quickshell/greeter/greeter.qml
      SESSION_WRAPPER=/etc/greetd/session-wrapper

      # Crash guard: fall back to agreety after 3 rapid crashes
      if [ -f "$CRASH_FILE" ] && [ $(($(date +%s) - $(stat -c %Y "$CRASH_FILE"))) -lt 30 ]; then
        count=$(cat "$CRASH_FILE")
      else
        count=0
      fi
      count=$((count + 1))
      echo "$count" > "$CRASH_FILE"

      if [ "$count" -ge 3 ]; then
        echo 0 > "$CRASH_FILE"
        echo "greeter: crash guard reached, falling back to agreety" >&2
        exec "$AGREETY" --cmd "$SESSION_WRAPPER"
      fi

      # Check if we have GPU/drm for Hyprland
      if [ ! -e /dev/dri/card0 ] || [ ! -f "$GREETER_QML" ]; then
        echo "greeter: no GPU or no QML config, falling back to agreety" >&2
        exec "$AGREETY" --cmd "$SESSION_WRAPPER"
      fi

      echo "greeter: launching Hyprland greeter" >&2
      exec "$HYPRLAND" --config "$GREETER_CONF"
    '';

    # Session wrapper: launches user's Hyprland
    environment.etc."greetd/session-wrapper".source = pkgs.writeShellScript "greetd-session-wrapper" ''
      set -eu
      export HOME="$1"
      shift
      exec ${pkgs.hyprland}/bin/Hyprland "$@"
    '';

    services.greetd = {
      enable = true;
      restart = false;
      settings = {
        default_session = {
          command = "/etc/greetd/greeter-wrapper";
          user = "neg";
        };
      };
    };
  };
}
