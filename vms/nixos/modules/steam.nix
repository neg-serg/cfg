{ config, pkgs, lib, ... }:

let
  cfg = config._steam;
in
{
  options._steam.enable = lib.mkEnableOption "Steam gaming stack";

  config = lib.mkIf cfg.enable {

    # Steam with multilib (32-bit support)
    programs.steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
    };

    # Gamemode (performance tuning daemon)
    programs.gamemode.enable = true;

    environment.systemPackages = with pkgs; [
      lutris
      wine
      gamescope
      mangohud
      nethack
    ];

    # GPU acceleration — only useful with GPU passthrough
    # hardware.opengl = {
    #   enable = true;
    #   driSupport = true;
    #   driSupport32Bit = true;
    #   extraPackages = with pkgs; [
    #     amdvlk
    #     rocmPackages.clr.icd
    #   ];
    #   extraPackages32 = with pkgs; [
    #     driversi686Linux.amdvlk
    #   ];
    # };
  };
}
