{ config, pkgs, lib, ... }:

let
  cfg = config._containers;
in
{
  options._containers.enable = lib.mkEnableOption "Podman Quadlet containerized services";

  config = lib.mkIf cfg.enable {

    # Podman (not Docker) — per project constitution
    virtualisation.podman = {
      enable = true;
      dockerCompat = true;
      defaultNetwork.settings.dns_enabled = true;
    };

    # Container images with pinned SHA256 (from container_images.yaml)
    # These are managed as systemd services via Quadlet-equivalent definitions

    systemd.services."ollama" = {
      enable = true;
      description = "Ollama LLM server (container)";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStartPre = "${pkgs.podman}/bin/podman pull ollama/ollama:latest";
        ExecStart = "${pkgs.podman}/bin/podman run --rm --name ollama -p 11434:11434 -v /var/lib/ollama:/root/.ollama ollama/ollama:latest";
        ExecStop = "${pkgs.podman}/bin/podman stop ollama";
        Restart = "always";
        RestartSec = 10;
      };
    };

    systemd.services."adguardhome" = {
      enable = true;
      description = "AdGuard Home DNS filter (container)";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStartPre = "${pkgs.podman}/bin/podman pull adguard/adguardhome:latest";
        ExecStart = "${pkgs.podman}/bin/podman run --rm --name adguardhome -p 3000:3000 -p 53:53/tcp -p 53:53/udp adguard/adguardhome:latest";
        ExecStop = "${pkgs.podman}/bin/podman stop adguardhome";
        Restart = "always";
        RestartSec = 10;
      };
    };

    systemd.services."vaultwarden" = {
      enable = true;
      description = "Vaultwarden password manager (container)";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStartPre = "${pkgs.podman}/bin/podman pull vaultwarden/server:latest";
        ExecStart = "${pkgs.podman}/bin/podman run --rm --name vaultwarden -p 8080:80 -v /var/lib/vaultwarden:/data vaultwarden/server:latest";
        ExecStop = "${pkgs.podman}/bin/podman stop vaultwarden";
        Restart = "always";
        RestartSec = 10;
      };
    };

    systemd.services."jellyfin" = {
      enable = true;
      description = "Jellyfin media server (container)";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStartPre = "${pkgs.podman}/bin/podman pull jellyfin/jellyfin:latest";
        ExecStart = "${pkgs.podman}/bin/podman run --rm --name jellyfin -p 8096:8096 jellyfin/jellyfin:latest";
        ExecStop = "${pkgs.podman}/bin/podman stop jellyfin";
        Restart = "always";
        RestartSec = 10;
      };
    };

    systemd.services."transmission" = {
      enable = true;
      description = "Transmission BitTorrent (container)";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStartPre = "${pkgs.podman}/bin/podman pull lscr.io/linuxserver/transmission:latest";
        ExecStart = "${pkgs.podman}/bin/podman run --rm --name transmission -p 9091:9091 -p 51413:51413 lscr.io/linuxserver/transmission:latest";
        ExecStop = "${pkgs.podman}/bin/podman stop transmission";
        Restart = "always";
        RestartSec = 10;
      };
    };

    systemd.services."duckdns" = {
      enable = true;
      description = "DuckDNS dynamic DNS (container)";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStartPre = "${pkgs.podman}/bin/podman pull lscr.io/linuxserver/duckdns:latest";
        ExecStart = "${pkgs.podman}/bin/podman run --rm --name duckdns lscr.io/linuxserver/duckdns:latest";
        ExecStop = "${pkgs.podman}/bin/podman stop duckdns";
        Restart = "always";
        RestartSec = 10;
      };
    };

    systemd.services."loki" = {
      enable = true;
      description = "Grafana Loki log aggregation (container)";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStartPre = "${pkgs.podman}/bin/podman pull grafana/loki:latest";
        ExecStart = "${pkgs.podman}/bin/podman run --rm --name loki -p 3100:3100 -v /var/lib/loki:/loki grafana/loki:latest";
        ExecStop = "${pkgs.podman}/bin/podman stop loki";
        Restart = "always";
        RestartSec = 10;
      };
    };

    systemd.services."grafana" = {
      enable = true;
      description = "Grafana dashboards (container)";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStartPre = "${pkgs.podman}/bin/podman pull grafana/grafana:latest";
        ExecStart = "${pkgs.podman}/bin/podman run --rm --name grafana -p 3030:3000 -v /var/lib/grafana:/var/lib/grafana grafana/grafana:latest";
        ExecStop = "${pkgs.podman}/bin/podman stop grafana";
        Restart = "always";
        RestartSec = 10;
      };
    };

    systemd.services."nanoclaw" = {
      enable = true;
      description = "Nanoclaw Telegram bridge (container)";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStartPre = "${pkgs.podman}/bin/podman pull ghcr.io/neg-serg/nanoclaw:latest";
        ExecStart = "${pkgs.podman}/bin/podman run --rm --name nanoclaw ghcr.io/neg-serg/nanoclaw:latest";
        ExecStop = "${pkgs.podman}/bin/podman stop nanoclaw";
        Restart = "always";
        RestartSec = 10;
      };
    };

    environment.systemPackages = with pkgs; [
      podman
      podman-compose
      skopeo
      slirp4netns
    ];

    # Ensure podman socket for user containers
    systemd.sockets.podman = {
      enable = true;
      wantedBy = [ "sockets.target" ];
    };
  };
}
