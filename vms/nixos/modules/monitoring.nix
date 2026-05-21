{ config, pkgs, lib, ... }:

let
  cfg = config._monitoring;
in
{
  options._monitoring.enable = lib.mkEnableOption "Loki, Grafana, Promtail, Alertmanager observability";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      grafana
      loki
      promtail
      alertmanager
      vnstat
      sysstat
    ];

    # Grafana (containerized — defined in containers.nix)
    # Loki (containerized — defined in containers.nix)
    # Promtail (containerized — defined in containers.nix)
    # Alertmanager (containerized — defined in containers.nix)

    # System monitoring
    services.sysstat.enable = true;
  };
}
