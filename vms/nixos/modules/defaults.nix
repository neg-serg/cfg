{ lib, ... }:

{
  # Feature toggles — equivalent to Salt's feature_registry.yaml
  # Set to false to disable a domain group
  _desktop.enable = lib.mkDefault true;
  _audio.enable = lib.mkDefault true;
  _network.enable = lib.mkDefault true;
  _containers.enable = lib.mkDefault true;
  _ai.enable = lib.mkDefault true;
  _monitoring.enable = lib.mkDefault true;
  _steam.enable = lib.mkDefault true;
  _dev.enable = lib.mkDefault true;
  _proxy.enable = lib.mkDefault true;

  # Phase 1 migration modules
  _flatpak.enable = lib.mkDefault true;
  _mpd.enable = lib.mkDefault true;
  _proxypilot.enable = lib.mkDefault true;
  _espanso.enable = lib.mkDefault true;
  _userServices.enable = lib.mkDefault true;
  _installers.enable = lib.mkDefault true;

  # VM testing: auto-login for SPICE testing (skip greeter)
  _desktop.autoLogin = lib.mkDefault true;
}
