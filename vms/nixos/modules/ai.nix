{ config, pkgs, lib, ... }:

let
  cfg = config._ai;
in
{
  options._ai.enable = lib.mkEnableOption "AI inference servers and tools";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      yt-dlp
      gallery-dl
      python3Packages.annoy  # Annoy approximate nearest neighbors
      (python3.withPackages (ps: with ps; [
        telethon
        openai
        huggingface-hub
        python-telegram-bot
        mutagen
        rapidgzip
        textual
        transformers
      ]))
    ];

    # ── Telethon Bridge (Telegram MTProto → HTTP relay) ──
    systemd.user.services.telethon-bridge = {
      description = "Telethon Telegram MTProto bridge";
      after = [ "network.target" ];
      wantedBy = [ "default.target" ];
      serviceConfig = {
        Type = "simple";
        Restart = "on-failure";
        RestartSec = 10;
        ExecStart = "${pkgs.bash}/bin/bash -c 'mkdir -p %h/.config/telethon-bridge %h/.local/state/telethon-bridge/media && exec ${pkgs.python3}/bin/python -m telethon_bridge 2>/dev/null || sleep infinity'";
      };
    };

    # ── Managed Bots (Telegram Bot API manager) ──
    systemd.user.services.managed-bots = {
      description = "Managed Telegram bots";
      after = [ "network.target" ];
      wantedBy = [ "default.target" ];
      serviceConfig = {
        Type = "simple";
        Restart = "on-failure";
        RestartSec = 15;
        ExecStart = "${pkgs.bash}/bin/bash -c 'mkdir -p %h/.config/opencode && exec ${pkgs.python3}/bin/python %h/src/cfg/states/scripts/managed-bots-runner.py 2>/dev/null || sleep infinity'";
      };
    };

    # ── Music Index (BPM/key/fingerprint pipeline) ──
    systemd.user.services.music-index = {
      description = "Music analysis and indexing";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.bash}/bin/bash -c 'echo \"Music index: run analysis script manually\"'";
      };
    };

    systemd.user.timers.music-index = {
      description = "Periodic music indexing";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
      };
    };

    # ── Image Generation provider config stub ──
    systemd.tmpfiles.rules = [
      "d /home/neg/.config/image-gen 0755 neg users -"
    ];
  };
}
