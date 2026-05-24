{ config, pkgs, lib, ... }:

let
  cfg = config._proxypilot;
in
{
  options._proxypilot.enable = lib.mkEnableOption "ProxyPilot LLM API proxy service";

  config = lib.mkIf cfg.enable {
    # ProxyPilot binary comes from custom pkgs overlay (pkgs/proxypilot.nix)
    environment.systemPackages = with pkgs; [ proxypilot ];

    # Config directory
    systemd.tmpfiles.rules = [
      "d /home/neg/.config/proxypilot 0700 neg users -"
    ];

    # ProxyPilot systemd service — runs the native binary
    # Config file at ~/.config/proxypilot/config.yaml is managed by chezmoi or manually
    systemd.services.proxypilot = {
      description = "ProxyPilot LLM API proxy";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        User = "neg";
        Restart = "always";
        RestartSec = 5;
        ExecStart = "${pkgs.proxypilot}/bin/proxypilot --config /home/neg/.config/proxypilot/config.yaml";
        # Limit memory to prevent OOM on large LLM responses
        MemoryMax = "512M";
      };
    };

    # Health check — ProxyPilot listens on port 8080 by default
    systemd.services.proxypilot-healthcheck = {
      description = "ProxyPilot health check and auto-restart";
      after = [ "proxypilot.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        User = "neg";
      };
      script = ''
        if ! ${pkgs.curl}/bin/curl -sf http://127.0.0.1:8080/health >/dev/null 2>&1; then
          echo "ProxyPilot health check failed — restarting"
          ${pkgs.systemd}/bin/systemctl restart proxypilot
        fi
      '';
    };

    systemd.timers.proxypilot-healthcheck = {
      description = "Periodic ProxyPilot health check";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "minutely";
        Persistent = true;
      };
    };
  };
}
