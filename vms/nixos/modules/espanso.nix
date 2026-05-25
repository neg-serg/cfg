{ config, pkgs, lib, ... }:

let
  cfg = config._espanso;
in
{
  options._espanso.enable = lib.mkEnableOption "Espanso text expander service";

  config = lib.mkIf cfg.enable {
    # Espanso text expander — use NixOS built-in module
    services.espanso = {
      enable = true;
    };

    # Configuration file is managed by chezmoi (dotfiles/dot_config/espanso/)
    # Ensure config directory exists
    systemd.tmpfiles.rules = [
      "d /home/neg/.config/espanso 0755 neg users -"
      "d /home/neg/.config/espanso/match 0755 neg users -"
      "d /home/neg/.config/espanso/config 0755 neg users -"
    ];
  };
}
