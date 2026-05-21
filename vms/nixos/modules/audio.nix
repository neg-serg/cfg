{ config, pkgs, lib, ... }:

let
  cfg = config._audio;
in
{
  options._audio.enable = lib.mkEnableOption "PipeWire audio stack";

  config = lib.mkIf cfg.enable {

    # PipeWire server
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;
    };

    # WirePlumber session manager
    services.pipewire.wireplumber.enable = true;

    # ALSA configuration
    environment.systemPackages = with pkgs; [
      alsa-utils
      playerctl
      pavucontrol
      helvum  # PipeWire patchbay
      qpwgraph  # PipeWire graph
      carla  # Audio plugin host
      lsp-plugins
    ];

    # Audio group for real-time privileges
    security.rtkit.enable = true;
    users.groups.audio = {};

    # RME HDSPe — deferred (PCIe passthrough not feasible in QEMU VM)
    # Reference: docs/hdspe-post-install.md
    # Set up when running on bare metal with GPU/PCIe passthrough
  };
}
