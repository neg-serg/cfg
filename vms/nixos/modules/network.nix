{ config, pkgs, lib, ... }:

let
  cfg = config._network;
in
{
  options._network.enable = lib.mkEnableOption "VPN, DNS, firewall, IPv6, DPI bypass";

  config = lib.mkIf cfg.enable {

    # Firewall — iptables
    networking.firewall.enable = true;

    # Unbound recursive DNS resolver
    services.unbound = {
      enable = true;
      settings = {
        server = {
          interface = [ "127.0.0.1" "::1" ];
          access-control = [ "127.0.0.0/8 allow" "::1 allow" ];
          port = 5335;
          prefetch = "yes";
        };
      };
    };

    # DNS-over-TLS via systemd-resolved (if available)
    services.resolved = {
      enable = true;
      dnssec = "true";
      fallbackDns = [ "8.8.8.8" "1.1.1.1" ];
    };

    # Avahi mDNS
    services.avahi = {
      enable = true;
      nssmdns4 = true;
      publish = {
        enable = true;
        workstation = true;
      };
    };

    # Tailscale mesh VPN
    services.tailscale.enable = true;

    # sing-box (hybrid VPN TUN) — NixOS service
    systemd.services.sing-box = {
      enable = false;  # requires config from data/vpn.yaml
      description = "sing-box TUN service";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.sing-box}/bin/sing-box run -c /etc/sing-box/config.json";
        Restart = "always";
      };
    };

    # Xray VPN proxy (VPN bypass for RF)
    systemd.services.xray = {
      enable = false;  # requires config from data/vpn.yaml
      description = "Xray VPN proxy";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.xray}/bin/xray run -c /etc/xray/config.json";
        Restart = "always";
      };
    };

    # zapret2 DPI bypass — nfqueue-based
    # Deferred to network config from data/zapret2.yaml

    environment.systemPackages = with pkgs; [
      nmap
      nethogs
      doggo
      mtr
      iperf3
      bandwhich
      tcpdump
      tailscale
      sing-box
      v2raya
    ];
  };
}
