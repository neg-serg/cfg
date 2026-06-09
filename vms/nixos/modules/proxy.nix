{ config, pkgs, lib, proxyHost ? "", proxyPort ? "10808", ... }:

let
  cfg = config._proxy;
  proxyUrl = if proxyHost != "" then "socks5://${proxyHost}:${proxyPort}" else "";
  proxyEnabled = cfg.enable && proxyHost != "";
in
{
  options._proxy.enable = lib.mkEnableOption "SOCKS5 proxy passthrough for Nix daemon and system services";

  config = lib.mkIf proxyEnabled {

    # Nix daemon proxy environment
    systemd.services.nix-daemon.environment = {
      ALL_PROXY = proxyUrl;
      all_proxy = proxyUrl;
      HTTP_PROXY = proxyUrl;
      HTTPS_PROXY = proxyUrl;
    };

    # System-wide proxy environment
    environment.variables = {
      ALL_PROXY = proxyUrl;
      all_proxy = proxyUrl;
      HTTP_PROXY = proxyUrl;
      HTTPS_PROXY = proxyUrl;
    };

    # Nix settings for proxy awareness
    nix.settings = {
      http-connections = 25;
      connect-timeout = 30;
    };
  };
}
