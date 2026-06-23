{ config, pkgs, lib, ... }:

let
  cfg = config._filesystems;
in
{
  options._filesystems.enable = lib.mkEnableOption "Additional filesystems (bind mounts, external storage)";

  config = lib.mkIf cfg.enable {
    # Only mount what's needed. LVM volumes /mnt/one, /mnt/zero added
    # later via nixos-rebuild when user is ready.
  };
}
