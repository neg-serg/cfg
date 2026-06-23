{ config, pkgs, lib, ... }:

let
  cfg = config._filesystems;
in
{
  options._filesystems.enable = lib.mkEnableOption "Additional filesystems (Windows NTFS + bind mounts)";

  config = lib.mkIf cfg.enable {
    # CachyOS root (read-only, for chezmoi dotfiles via ~/src)
    fileSystems."/mnt/cachyos" = {
      device = "/dev/nvme0n1p4";
      fsType = "xfs";
      options = [ "nofail" "ro" "noauto" ];
    };
  };
}
