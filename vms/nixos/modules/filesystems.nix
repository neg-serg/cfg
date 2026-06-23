{ config, pkgs, lib, ... }:

let
  cfg = config._filesystems;
in
{
  options._filesystems.enable = lib.mkEnableOption "Additional filesystems (Windows NTFS + bind mounts)";

  config = lib.mkIf cfg.enable {
    # Windows NTFS partition — automount on idle
    fileSystems."/mnt/windows" = {
      device = "/dev/disk/by-uuid/86286AAE286A9CC5";
      fsType = "ntfs3";
      options = [ "rw" "nofail" "x-systemd.automount" "x-systemd.idle-timeout=60" ];
    };

    # Bind mounts for external storage directories
    fileSystems."/home/neg/.local/mail" = {
      device = "/mnt/zero/mail";
      fsType = "none";
      options = [ "bind" "nofail" "x-systemd.requires-mounts-for=/mnt/zero" ];
    };
    fileSystems."/home/neg/music" = {
      device = "/mnt/one/music";
      fsType = "none";
      options = [ "bind" "nofail" "x-systemd.requires-mounts-for=/mnt/one" ];
    };
    fileSystems."/home/neg/vid" = {
      device = "/mnt/one/vid";
      fsType = "none";
      options = [ "bind" "nofail" "x-systemd.requires-mounts-for=/mnt/one" ];
    };
    fileSystems."/home/neg/doc" = {
      device = "/mnt/one/doc";
      fsType = "none";
      options = [ "bind" "nofail" "x-systemd.requires-mounts-for=/mnt/one" ];
    };
    fileSystems."/home/neg/torrent" = {
      device = "/mnt/one/torrent";
      fsType = "none";
      options = [ "bind" "nofail" "x-systemd.requires-mounts-for=/mnt/one" ];
    };
    fileSystems."/home/neg/games" = {
      device = "/mnt/zero/games";
      fsType = "none";
      options = [ "bind" "nofail" "x-systemd.requires-mounts-for=/mnt/zero" ];
    };
  };
}
