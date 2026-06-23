{ config, pkgs, lib, ... }:

let
  cfg = config._duckdns;
in
{
  options._duckdns.enable = lib.mkEnableOption "DuckDNS dynamic DNS updater";

  config = lib.mkIf cfg.enable {
    systemd.services.duckdns-update = {
      description = "DuckDNS dynamic DNS update";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.curl}/bin/curl -s -o /dev/null \"https://www.duckdns.org/update?domains=nixos-telfir&token=DUCKDNS_TOKEN_PLACEHOLDER\"";
        User = "nobody";
        ProtectSystem = "strict";
        PrivateTmp = true;
      };
    };

    systemd.timers.duckdns-update = {
      description = "DuckDNS periodic update timer";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "1min";
        OnUnitActiveSec = "5min";
        Persistent = true;
      };
    };
  };
}
