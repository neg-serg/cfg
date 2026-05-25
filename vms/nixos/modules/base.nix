{ config, pkgs, lib, ... }:

{
  imports = [];

  system.stateVersion = "25.05";
  networking.hostName = "nixos";

  # Users
  users.users.root = {
    hashedPassword = "!";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEx7F9KuTtPsLj9UVtUQ9ZrXUebjCMKuKZcyZWzg2RHf serg.zorg@gmail.com"
    ];
  };

  users.users.nixos = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEx7F9KuTtPsLj9UVtUQ9ZrXUebjCMKuKZcyZWzg2RHf serg.zorg@gmail.com"
    ];
  };

  users.users.neg = {
    isNormalUser = true;
    extraGroups = [ "wheel" "video" "render" "input" "seat" "audio" "networkmanager" ];
    home = "/home/neg";
    initialPassword = "nixos";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEx7F9KuTtPsLj9UVtUQ9ZrXUebjCMKuKZcyZWzg2RHf serg.zorg@gmail.com"
    ];
  };

  # Seatd — allows Hyprland to access /dev/dri/card0 and /dev/input/* through seat
  services.seatd.enable = true;

  # Syncthing — P2P file synchronization
  services.syncthing = {
    enable = true;
    user = "neg";
  };

  # Passwordless sudo for neg (needed for nixos-rebuild switch in VM)
  security.sudo.extraRules = [
    { users = [ "neg" ]; groups = [ "wheel" ]; commands = [ { command = "ALL"; options = [ "NOPASSWD" ]; } ]; }
  ];

  # Locale
  i18n.defaultLocale = "en_US.UTF-8";
  time.timeZone = "Europe/Moscow";

  # SSH
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
  };

  # Boot — systemd-boot for UEFI
  # VM: grub instead (no /boot mount needed), or use --no-install-bootloader
  boot.loader.systemd-boot.enable = lib.mkDefault true;
  boot.loader.efi.canTouchEfiVariables = lib.mkDefault false;
  # Prevent bootloader errors when /boot isn't mounted (e.g. in VM)
  boot.loader.efi.efiSysMountPoint = lib.mkDefault "/boot";
  boot.kernelParams = [ "quiet" "console=ttyS0,115200n8" ];
  boot.initrd.availableKernelModules = [
    "virtio_scsi" "virtio_blk" "virtio_net" "vfat" "zstd" "virtio-gpu"
  ];

  # Network (uses networkd with DHCP)
  systemd.network.enable = true;
  networking.useNetworkd = true;

  # QEMU guest agent
  services.qemuGuest.enable = true;

  # VM disk size — 50G for closure (~30G) + swapfile (8G) + headroom
  virtualisation.diskSize = 51200;

  # Allow unfree packages (Steam, etc.)
  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.doCheckByDefault = false;
  nixpkgs.overlays = [
    (final: prev: {
      openldap = prev.openldap.overrideAttrs (_: { doCheck = false; });
    })
  ];

  # Nix settings — Determinate Nix cache
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    substituters = [ "https://install.determinate.systems" ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "install.determinate.systems:2/bvnFWPrR6uxEXpB7XqOSykYemH8e8WoMWvoLLXpF4="
    ];
    http-connections = 25;
    accept-flake-config = true;
  };

  # PC/SC daemon for YubiKey smart card access
  services.pcscd.enable = true;

  # Environment matching Salt/chezmoi conventions
  environment.variables = {
    PASSWORD_STORE_DIR = "/home/neg/.local/share/pass";
    GNUPGHOME = "/home/neg/.local/share/gnupg";
  };

  environment.sessionVariables = {
    XDG_MUSIC_DIR = "/home/neg/music";
    XDG_PICTURES_DIR = "/home/neg/pic";
    XDG_VIDEOS_DIR = "/home/neg/vid";
    XDG_DOCUMENTS_DIR = "/home/neg/doc";
    XDG_DOWNLOAD_DIR = "/home/neg/dw";
  };

  # Create custom XDG and secrets directories for neg user
  systemd.services.fixHomeConfigPermissions = {
    description = "Fix /home/neg/.config ownership";
    after = [ "systemd-tmpfiles-setup.service" ];
    before = [ "systemd-user-sessions.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      chown -R neg:users /home/neg/.config 2>/dev/null || true
      chown neg:users /home/neg/.local /home/neg/.local/share 2>/dev/null || true
      mkdir -p /home/neg/.config/age
      chmod 700 /home/neg/.config/age
      chown neg:users /home/neg/.config/age
    '';
  };

  systemd.tmpfiles.rules = [
    "d /home/neg/music 0755 neg users -"
    "d /home/neg/pic 0755 neg users -"
    "d /home/neg/vid 0755 neg users -"
    "d /home/neg/doc 0755 neg users -"
    "d /home/neg/dw 0755 neg users -"
    "d /home/neg/.local/share/pass 0700 neg users -"
    "d /home/neg/.local/share/gnupg 0700 neg users -"
    "z /home/neg/.local 0755 neg users -"
    "z /home/neg/.local/share 0755 neg users -"
  ];

  # Swap (4GB swapfile on root) — already created by VM runner
  swapDevices = [ { device = "/swapfile"; size = 4096; } ];

  # Sysctl tuning (from Salt sysctl-custom.conf)
  boot.kernel.sysctl = {
    # Kernel security
    "kernel.sysrq" = 0;
    "kernel.dmesg_restrict" = 1;
    "kernel.unprivileged_bpf_disabled" = 1;
    "net.core.bpf_jit_harden" = 2;
    # IP forwarding (VPN/containers)
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
    # TCP hardening
    "net.ipv4.icmp_ignore_bogus_error_responses" = 1;
    "net.ipv4.conf.default.rp_filter" = 1;
    "net.ipv4.conf.all.rp_filter" = 1;
    "net.ipv4.conf.all.accept_source_route" = 0;
    "net.ipv6.conf.all.accept_source_route" = 0;
    "net.ipv4.tcp_syncookies" = 1;
    "net.ipv4.tcp_rfc1337" = 1;
    # Log martians
    "net.ipv4.conf.all.log_martians" = 1;
    "net.ipv4.conf.default.log_martians" = 1;
    # TCP optimization
    "net.ipv4.tcp_fastopen" = 3;
    "net.ipv4.tcp_mtu_probing" = 1;
    "net.ipv4.tcp_congestion_control" = "bbr";
    "net.core.default_qdisc" = "fq";
    # Memory tuning
    "vm.swappiness" = 10;
    "vm.vfs_cache_pressure" = 50;
    "vm.max_map_count" = 16777216;
    "vm.nr_hugepages" = 8192;
    # Writeback tuning
    "vm.dirty_background_bytes" = 67108864;
    "vm.dirty_bytes" = 268435456;
    "vm.dirty_expire_centisecs" = 3000;
    "vm.dirty_writeback_centisecs" = 500;
    # Gaming latency
    "vm.compaction_proactiveness" = 0;
  };
}
