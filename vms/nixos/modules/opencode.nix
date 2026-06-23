{ config, pkgs, lib, ... }:

let
  cfg = config._opencode;
in
{
  options._opencode.enable = lib.mkEnableOption "OpenCode AI coding agent daemon";

  config = lib.mkIf cfg.enable {
    systemd.user.services.opencode-daemon = {
      description = "OpenCode AI coding agent daemon";
      after = [ "network.target" ];
      wantedBy = [ "default.target" ];
      serviceConfig = {
        Type = "simple";
        Restart = "on-failure";
        RestartSec = 10;
        ExecStart = "${pkgs.opencode}/bin/opencode serve";
        Environment = "HOME=%h";
      };
    };
  };
}
