{ config, pkgs, lib, ... }:

let
  cfg = config._mpd;
in
{
  options._mpd.enable = lib.mkEnableOption "MPD music player daemon with Last.fm scrobbling";

  config = lib.mkIf cfg.enable {
    # MPD server — NixOS built-in module
    services.mpd = {
      enable = true;
      user = "neg";
      group = "users";
      musicDirectory = "/home/neg/music";
      playlistDirectory = "/home/neg/.config/mpd/playlists";
      dbFile = "/home/neg/.local/share/mpd/database";
      network = {
        listenAddress = "127.0.0.1";
        port = 6600;
      };
      settings = {
        audio_output = [
          {
            name = "PipeWire";
            type = "pipewire";
          }
          {
            name = "fifo";
            type = "fifo";
            path = "/tmp/mpd.fifo";
            format = "44100:16:2";
          }
        ];
        auto_update = "yes";
      };
    };

    # Create MPD directories
    systemd.tmpfiles.rules = [
      "d /home/neg/.local/share/mpd 0755 neg users -"
      "d /home/neg/.config/mpd/playlists 0755 neg users -"
    ];

    # mpdas — Last.fm scrobbler for MPD
    # Config is generated at runtime from age secrets (lastfm username/password)
    systemd.services.mpdas = {
      description = "MPD Audio Scrobbler (Last.fm)";
      after = [ "mpd.service" "network.target" ];
      wants = [ "mpd.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        User = "neg";
        Restart = "on-failure";
        RestartSec = 5;
        ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p /home/neg/.config";
        ExecStart = "${pkgs.writeShellScript "mpdas-wrapper" ''
          set -euo pipefail
          CONFIG_FILE="/home/neg/.config/mpdasrc"
          if [ -f "/run/secrets/lastfm-username" ] && [ -f "/run/secrets/lastfm-password" ]; then
            USERNAME="$(cat /run/secrets/lastfm-username | tr -d '\n')"
            PASSWORD="$(cat /run/secrets/lastfm-password | tr -d '\n')"
            cat > "$CONFIG_FILE" << EOF
        host = localhost
        port = 6600
        service = lastfm
        username = $USERNAME
        password = $PASSWORD
EOF
            chmod 0600 "$CONFIG_FILE"
          fi
          exec ${pkgs.mpdas}/bin/mpdas
        ''}";
      };
    };

    # mpDris2 — MPRIS bridge for MPD
    systemd.user.services.mpDris2 = {
      enable = true;
      description = "MPD MPRIS bridge";
      after = [ "mpd.service" ];
      wants = [ "mpd.service" ];
      serviceConfig = {
        Type = "simple";
        Restart = "always";
        RestartSec = 3;
        ExecStart = "${pkgs.mpdris2}/bin/mpDris2";
      };
      wantedBy = [ "default.target" ];
    };

    # Packages
    environment.systemPackages = with pkgs; [
      mpc          # MPD client
      mpdas        # Last.fm scrobbler
      mpdris2      # MPRIS bridge (mpDris2)
      wiremix      # MPD visualizer (from custom pkgs)
    ];
  };
}
