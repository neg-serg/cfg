{ config, pkgs, lib, ... }:

let
  cfg = config._filesystems;
in
{
  options._filesystems.enable = lib.mkEnableOption "Additional filesystems (Windows NTFS + bind mounts)";

  config = lib.mkIf cfg.enable {
    # CachyOS root (for src/cfg dotfiles access)
    fileSystems."/mnt/cachyos" = {
      device = "/dev/nvme0n1p4";
      fsType = "xfs";
      options = [ "nofail" "ro" ];
    };
    fileSystems."/mnt/windows" = {
      device = "/dev/disk/by-uuid/86286AAE286A9CC5";
      fsType = "ntfs3";
      options = [ "rw" "nofail" "x-systemd.automount" "x-systemd.idle-timeout=60" ];
    };

    # Bind mounts for external storage directories (require /mnt/one, /mnt/zero)
    fileSystems."/home/neg/.local/mail" = {
      device = "/mnt/zero/mail";
      fsType = "none";
      options = [ "bind" "nofail" "noauto" "x-systemd.automount" ];
    };
    fileSystems."/home/neg/music" = {
      device = "/mnt/one/music";
      fsType = "none";
      options = [ "bind" "nofail" "noauto,x-systemd.automount" ];
    };
    fileSystems."/home/neg/vid" = {
      device = "/mnt/one/vid";
      fsType = "none";
      options = [ "bind" "nofail" "noauto,x-systemd.automount" ];
    };
    fileSystems."/home/neg/doc" = {
      device = "/mnt/one/doc";
      fsType = "none";
      options = [ "bind" "nofail" "noauto,x-systemd.automount" ];
    };
    fileSystems."/home/neg/torrent" = {
      device = "/mnt/one/torrent";
      fsType = "none";
      options = [ "bind" "nofail" "noauto,x-systemd.automount" ];
    };
    fileSystems."/home/neg/games" = {
      device = "/mnt/zero/games";
      fsType = "none";
      options = [ "bind" "nofail" "noauto,x-systemd.automount" ];
    };
  };
}
