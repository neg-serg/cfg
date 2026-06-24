{ config, pkgs, lib, ... }:

let
  cfg = config._filesystems;
in
{
  options._filesystems.enable = lib.mkEnableOption "Additional filesystems (bind mounts, external storage)";

  config = lib.mkIf cfg.enable {
    # LVM volumes — automount on first access, don't block boot
    fileSystems."/mnt/one" = {
      device = "/dev/xenon/one";
      fsType = "xfs";
      options = [ "nofail" "noauto" "x-systemd.automount" "x-systemd.idle-timeout=60" ];
    };
    fileSystems."/mnt/zero" = {
      device = "/dev/argon/zero";
      fsType = "xfs";
      options = [ "nofail" "noauto" "x-systemd.automount" "x-systemd.idle-timeout=60" ];
    };
  };
}
