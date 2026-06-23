{ config, pkgs, lib, ... }:

let
  cfg = config._zenProfiles;
in
{
  options._zenProfiles.enable = lib.mkEnableOption "Zen Browser multi-profile directories";

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d /home/neg/.config/zen 0755 neg users -"
      "d /home/neg/.config/zen/neg 0755 neg users -"
      "d /home/neg/.config/zen/neg-work 0755 neg users -"
    ];
  };
}
