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
    systemd.user.services.chezmoi-watch = {
      enable = true;
      description = "Chezmoi file watcher for auto-apply";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.bash}/bin/bash -c 'cd /home/neg/.local/share/chezmoi && ${pkgs.chezmoi}/bin/chezmoi reapply 2>/dev/null || true'";
        ExecStartPost = "${pkgs.systemd}/bin/systemctl --user start chezmoi-watch.timer 2>/dev/null || true";
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
  };
}
