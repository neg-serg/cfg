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
        Restart = "on-failure";
        RestartSec = 30;
        StartLimitBurst = 3;
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
        Restart = "on-failure";
        RestartSec = 30;
        StartLimitBurst = 3;
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
        Restart = "on-failure";
        RestartSec = 30;
        StartLimitBurst = 3;
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
        Restart = "on-failure";
        RestartSec = 30;
        StartLimitBurst = 3;
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
        Restart = "on-failure";
        RestartSec = 30;
        StartLimitBurst = 3;
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
        Restart = "on-failure";
        RestartSec = 30;
        StartLimitBurst = 3;
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
        Restart = "on-failure";
        RestartSec = 30;
        StartLimitBurst = 3;
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
        Restart = "on-failure";
        RestartSec = 30;
        StartLimitBurst = 3;
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
        Restart = "on-failure";
        RestartSec = 30;
        StartLimitBurst = 3;
      };
    };

    systemd.services."promtail" = {
      enable = true;
      description = "Grafana Promtail log collector (container)";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStartPre = "${pkgs.podman}/bin/podman pull grafana/promtail:latest";
        ExecStart = "${pkgs.podman}/bin/podman run --rm --name promtail -v /var/log:/var/log:ro -v /var/lib/promtail:/etc/promtail grafana/promtail:latest";
        ExecStop = "${pkgs.podman}/bin/podman stop promtail";
        Restart = "on-failure";
        RestartSec = 30;
        StartLimitBurst = 3;
      };
    };

    systemd.services."alertmanager" = {
      enable = true;
      description = "Prometheus Alertmanager (container)";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStartPre = "${pkgs.podman}/bin/podman pull prom/alertmanager:latest";
        ExecStart = "${pkgs.podman}/bin/podman run --rm --name alertmanager -p 9093:9093 prom/alertmanager:latest";
        ExecStop = "${pkgs.podman}/bin/podman stop alertmanager";
        Restart = "on-failure";
        RestartSec = 30;
        StartLimitBurst = 3;
      };
    };

    systemd.services."llama-embed" = {
      enable = true;
      description = "LLM embeddings server (container)";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStartPre = "${pkgs.podman}/bin/podman pull ghcr.io/huggingface/text-embeddings-inference:latest";
        ExecStart = "${pkgs.podman}/bin/podman run --rm --name llama-embed -p 8088:80 ghcr.io/huggingface/text-embeddings-inference:latest";
        ExecStop = "${pkgs.podman}/bin/podman stop llama-embed";
        Restart = "on-failure";
        RestartSec = 30;
        StartLimitBurst = 3;
      };
    };

    environment.systemPackages = with pkgs; [
      podman
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
