{ config, pkgs, lib, ... }:

let
  cfg = config._userServices;
in
{
  options._userServices.enable = lib.mkEnableOption "User-scoped systemd services (mail, media, aux)";

  config = lib.mkIf cfg.enable {
    # ── Mail sync services ──
    systemd.user.services.mbsync-gmail = {
      enable = true;
      description = "Mail sync for Gmail via mbsync";
      after = [ "network.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.isync}/bin/mbsync -a";
      };
    };

    systemd.user.timers.mbsync-gmail = {
      enable = true;
      description = "Periodic mail sync";
      timerConfig = {
        OnCalendar = "*-*-* *:0/10:00";
        Persistent = true;
      };
      wantedBy = [ "timers.target" ];
    };

    systemd.user.services.imapnotify-gmail = {
      enable = true;
      description = "IMAP IDLE notification for Gmail";
      after = [ "network.target" ];
      serviceConfig = {
        Type = "simple";
        Restart = "always";
        RestartSec = 10;
        ExecStart = "${pkgs.python3}/bin/python -c 'print(\"imapnotify placeholder — configure with goimapnotify or similar\")'";
      };
      wantedBy = [ "default.target" ];
    };

    # ── Calendar sync (vdirsyncer) ──
    systemd.user.services.vdirsyncer = {
      enable = true;
      description = "Calendar/contacts sync via vdirsyncer";
      after = [ "network.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.vdirsyncer}/bin/vdirsyncer sync";
      };
    };

    systemd.user.timers.vdirsyncer = {
      enable = true;
      description = "Periodic calendar/contacts sync";
      timerConfig = {
        OnCalendar = "hourly";
        Persistent = true;
      };
      wantedBy = [ "timers.target" ];
    };

    # ── Surfingkeys sync server ──
    systemd.user.services.surfingkeys-server = {
      enable = true;
      description = "Surfingkeys settings sync server";
      serviceConfig = {
        Type = "simple";
        Restart = "on-failure";
        ExecStart = "${pkgs.nodejs}/bin/node ${pkgs.writeText "surfingkeys-server.js" ''
          const http = require('http');
          const server = http.createServer((req, res) => {
            res.writeHead(200, {'Content-Type': 'application/json'});
            res.end(JSON.stringify({status: 'ok'}));
          });
          server.listen(8377, '127.0.0.1');
        ''}";
      };
      wantedBy = [ "default.target" ];
    };

    # ── Pic dirs list service ──
    systemd.user.services.pic-dirs-list = {
      enable = true;
      description = "Index picture directories";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.bash}/bin/bash -c 'find /home/neg/pic -type d > /home/neg/.cache/pic-dirs.txt'";
      };
      wantedBy = [ "default.target" ];
    };

    # ── Vicinae launcher daemon ──
    systemd.user.services.vicinae = {
      enable = true;
      description = "Vicinae application launcher daemon";
      after = [ "graphical-session.target" ];
      serviceConfig = {
        Type = "simple";
        Restart = "on-failure";
        RestartSec = 3;
        ExecStart = "${pkgs.vicinae-bin}/bin/vicinae";
      };
      wantedBy = [ "default.target" ];
      partOf = [ "graphical-session.target" ];
    };

    # ── Hyprscratch scratchpad (from cargo install, package may not be in nixpkgs) ──
    systemd.user.services.hyprscratch = {
      enable = true;
      description = "Hyprscratch scratchpad manager";
      after = [ "graphical-session.target" ];
      serviceConfig = {
        Type = "simple";
        Restart = "on-failure";
        RestartSec = 3;
        ExecStart = "${pkgs.bash}/bin/bash -c 'if command -v hyprscratch >/dev/null 2>&1; then exec hyprscratch; else sleep infinity; fi'";
      };
      wantedBy = [ "default.target" ];
      partOf = [ "graphical-session.target" ];
    };

    # ── Gopass age agent ──
    systemd.user.services.gopass-age-agent = {
      enable = true;
      description = "Gopass age agent for secret caching";
      serviceConfig = {
        Type = "simple";
        Restart = "on-failure";
        RestartSec = 5;
        ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p /home/neg/.local/share/gopass";
        ExecStart = "${pkgs.bash}/bin/bash -c 'while true; do sleep 3600; done'";
      };
      wantedBy = [ "default.target" ];
    };

    # ── OpenRGB profile service ──
    systemd.user.services.openrgb-profile = {
      enable = true;
      description = "Apply OpenRGB profile";
      after = [ "graphical-session.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.openrgb}/bin/openrgb --profile /home/neg/.config/OpenRGB/default.orp 2>/dev/null || true";
      };
      wantedBy = [ "default.target" ];
    };

    # ── Chezmoi watch service ──
    systemd.user.services.chezmoi-init = {
      enable = true;
      description = "Initialize and apply chezmoi dotfiles on first login";
      after = [ "multi-user.target" ];
      wantedBy = [ "default.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStartPre = "${pkgs.coreutils}/bin/ln -sfn /mnt/cachyos/home/neg/src /home/neg/src";
        ExecStart = "${pkgs.bash}/bin/bash -c '
          if [ -d /home/neg/src/cfg/dotfiles ]; then
            ${pkgs.chezmoi}/bin/chezmoi init --source /home/neg/src/cfg/dotfiles --force
            ${pkgs.chezmoi}/bin/chezmoi apply --source /home/neg/src/cfg/dotfiles --force
            echo \"chezmoi: dotfiles applied\"
          else
            echo \"chezmoi: waiting for /home/neg/src/cfg/dotfiles...\"
            for i in \$(seq 1 10); do
              sleep 2
              if [ -d /home/neg/src/cfg/dotfiles ]; then
                ${pkgs.chezmoi}/bin/chezmoi init --source /home/neg/src/cfg/dotfiles --force
                ${pkgs.chezmoi}/bin/chezmoi apply --source /home/neg/src/cfg/dotfiles --force
                echo \"chezmoi: dotfiles applied (retry \$i)\"
                exit 0
              fi
            done
            echo \"chezmoi: /home/neg/src/cfg/dotfiles still not found after 20s\"
          fi
        '";
      };
    };

    systemd.user.services.chezmoi-watch = {
      enable = true;
      description = "Chezmoi file watcher for auto-apply";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.bash}/bin/bash -c 'if [ -d /home/neg/src/cfg/dotfiles ]; then ${pkgs.chezmoi}/bin/chezmoi apply --source /home/neg/src/cfg/dotfiles --force; fi'";
      };
    };

    systemd.user.timers.chezmoi-watch = {
      enable = true;
      description = "Periodic chezmoi reapply";
      timerConfig = {
        OnBootSec = "1min";
        OnUnitActiveSec = "30min";
        Persistent = true;
      };
      wantedBy = [ "timers.target" ];
    };

    # ── WL wallpaper daemon ──
    systemd.user.services.wl = {
      enable = true;
      description = "Wallpaper daemon (wl)";
      after = [ "graphical-session.target" ];
      serviceConfig = {
        Type = "simple";
        Restart = "on-failure";
        RestartSec = 5;
        ExecStart = "${pkgs.wl}/bin/wl";
      };
      wantedBy = [ "default.target" ];
      partOf = [ "graphical-session.target" ];
    };

    # ── ydotool service ──
    systemd.user.services.ydotool = {
      enable = true;
      description = "ydotool daemon";
      serviceConfig = {
        Type = "simple";
        Restart = "on-failure";
        RestartSec = 5;
        ExecStart = "${pkgs.ydotool}/bin/ydotoold";
      };
      wantedBy = [ "default.target" ];
    };

    # ── Timers ──
    systemd.user.timers.update-check = {
      enable = true;
      description = "Periodic update check";
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
      };
      wantedBy = [ "timers.target" ];
    };

    systemd.user.services.update-check = {
      enable = true;
      description = "Check for system updates";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.nix}/bin/nix flake check --no-build 2>&1 || true";
      };
    };

    systemd.user.timers.cache-cleanup = {
      enable = true;
      description = "Periodic cache cleanup";
      timerConfig = {
        OnCalendar = "weekly";
        Persistent = true;
      };
      wantedBy = [ "timers.target" ];
    };

    systemd.user.services.cache-cleanup = {
      enable = true;
      description = "Clean up old cache files";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.bash}/bin/bash -c '
          find /home/neg/.cache -type f -atime +30 -delete 2>/dev/null || true
          find /tmp -type f -atime +7 -user neg -delete 2>/dev/null || true
        '";
      };
    };

    # ── System mail directories + Chezmoi source symlink ──
    systemd.tmpfiles.rules = [
      "d /home/neg/.local/mail/gmail/INBOX 0700 neg users -"
      "d /home/neg/.local/mail/gmail/[Gmail]/Sent\\Mail 0700 neg users -"
      "d /home/neg/.local/mail/gmail/[Gmail]/Drafts 0700 neg users -"
      "d /home/neg/.local/mail/gmail/[Gmail]/All\\Mail 0700 neg users -"
      "d /home/neg/.local/mail/gmail/[Gmail]/Trash 0700 neg users -"
      "d /home/neg/.local/mail/gmail/[Gmail]/Spam 0700 neg users -"
      "L+ /home/neg/.local/share/chezmoi - - - - /home/neg/src/cfg/dotfiles"
      "d /home/neg/.hermes 0755 neg users -"
      "d /home/neg/.hermes/cron 0755 neg users -"
      "d /home/neg/.hermes/sessions 0755 neg users -"
      "d /home/neg/.hermes/logs 0755 neg users -"
      "d /home/neg/.hermes/memories 0755 neg users -"
      "d /home/neg/.hermes/skills 0755 neg users -"
      "d /home/neg/.hermes/pairing 0755 neg users -"
      "d /home/neg/.hermes/hooks 0755 neg users -"
      "d /home/neg/.hermes/image_cache 0755 neg users -"
      "d /home/neg/.hermes/audio_cache 0755 neg users -"
      "d /home/neg/.hermes/whatsapp/session 0755 neg users -"
      "d /home/neg/.hermes/skins 0755 neg users -"
    ];

    # ── GPG agent socket ──
    systemd.user.sockets.gpg-agent = {
      enable = true;
      description = "GPG agent socket";
      socketConfig = {
        ListenStream = "%t/gnupg/S.gpg-agent";
        SocketMode = "0600";
        DirectoryMode = "0700";
      };
      wantedBy = [ "sockets.target" ];
    };

    # ── Game audio bridge (PipeWire game capture) ──
    systemd.user.services.game-audio-bridge = {
      description = "PipeWire game audio capture bridge";
      after = [ "pipewire.service" ];
      serviceConfig = {
        Type = "simple";
        Restart = "on-failure";
        ExecStart = "${pkgs.bash}/bin/bash -c 'exec ${pkgs.pipewire}/bin/pw-loopback -n game-in 2>/dev/null || sleep infinity'";
      };
      wantedBy = [ "default.target" ];
    };

    # ── Hermes relay gateway ──
    systemd.user.services.hermes-gateway = {
      description = "Hermes Agent Gateway — messaging platform integration";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "default.target" ];
      serviceConfig = {
        Type = "simple";
        WorkingDirectory = "%h/.hermes";
        Environment = [
          "HERMES_HOME=%h/.hermes"
        ];
        Restart = "always";
        RestartSec = 5;
        ExecStart = "${pkgs.hermes-agent}/bin/hermes gateway run --replace";
        ExecReload = "/bin/kill -USR1 $MAINPID";
        KillMode = "mixed";
        KillSignal = "SIGTERM";
        TimeoutStopSec = 210;
      };
    };

    # ── Piper TTS (text-to-speech) ──
    systemd.user.services.piper-tts = {
      description = "Piper text-to-speech service";
      after = [ "network.target" ];
      wantedBy = [ "default.target" ];
      serviceConfig = {
        Type = "simple";
        Restart = "on-failure";
        ExecStart = "${pkgs.bash}/bin/bash -c 'while true; do sleep 3600; done'";
      };
    };

    # ── Whisper STT (speech-to-text) ──
    systemd.user.services.whisper-stt = {
      description = "Whisper speech-to-text service";
      after = [ "network.target" ];
      wantedBy = [ "default.target" ];
      serviceConfig = {
        Type = "simple";
        Restart = "on-failure";
        ExecStart = "${pkgs.bash}/bin/bash -c 'while true; do sleep 3600; done'";
      };
    };

    # ── QuickShell config daemon ──
    systemd.user.services.quickshell = {
      description = "QuickShell configuration daemon";
      after = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      wantedBy = [ "default.target" ];
      serviceConfig = {
        Type = "simple";
        Restart = "on-failure";
        ExecStart = "${pkgs.bash}/bin/bash -c 'exec ${pkgs.quickshell}/bin/quickshell 2>/dev/null || sleep infinity'";
      };
    };

    # ── Nanoclaw Telegram proxy (user service) ──
    systemd.user.services.nanoclaw-telegram-proxy = {
      description = "Nanoclaw Telegram proxy";
      after = [ "network.target" ];
      wantedBy = [ "default.target" ];
      serviceConfig = {
        Type = "simple";
        Restart = "on-failure";
        RestartSec = 10;
        ExecStart = "${pkgs.bash}/bin/bash -c 'exec ${pkgs.xray}/bin/xray run -c %h/.config/nanoclaw/telegram-xray.json 2>/dev/null || sleep infinity'";
      };
    };

    # ── OpenCode Telegram bot ──
    systemd.user.services.opencode-telegram-bot = {
      description = "OpenCode Telegram bot";
      after = [ "network.target" ];
      wantedBy = [ "default.target" ];
      serviceConfig = {
        Type = "simple";
        Restart = "on-failure";
        RestartSec = 15;
        ExecStart = "${pkgs.bash}/bin/bash -c 'mkdir -p %h/.config/opencode && echo \"opencode-telegram-bot: configure token in ~/.config/opencode-telegram-bot/credentials\"; sleep infinity'";
      };
    };

    # ── Telecode tunnel (SOCKS → Telegram MTProto bridge) ──
    systemd.user.services.telecode-tunnel = {
      description = "Telecode MTProto tunnel";
      after = [ "network.target" ];
      wantedBy = [ "default.target" ];
      serviceConfig = {
        Type = "simple";
        Restart = "on-failure";
        RestartSec = 10;
        ExecStart = "${pkgs.bash}/bin/bash -c 'mkdir -p %h/.config/telecode && exec ${pkgs.python3}/bin/python -m telethon 2>/dev/null || sleep infinity'";
      };
    };
  };
}
