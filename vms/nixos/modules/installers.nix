{ config, pkgs, lib, ... }:

let
  cfg = config._installers;
in
{
  options._installers.enable = lib.mkEnableOption "Fallback installers for tools not in nixpkgs (pip, cargo, go, binary)";

  config = lib.mkIf cfg.enable {
    # Certain tools are best installed via pipx (user-scope Python tools)
    # These are not available in nixpkgs or the nixpkgs version is outdated
    environment.systemPackages = with pkgs; [ pipx cargo-binstall ];
    # Systemd oneshot service to install pip-based tools
    systemd.services.pipx-install-tools = {
      description = "Install user-scope Python tools via pipx";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "neg";
      };
      script = let
        pipxTools = [
          # Tools from Salt's installers.sls that are not in nixpkgs
        ];
      in
        builtins.concatStringsSep "\n" (map (tool: ''
          if ! ${pkgs.pipx}/bin/pipx list --short 2>/dev/null | grep -q "^${tool} "; then
            ${pkgs.pipx}/bin/pipx install "${tool}" 2>&1 || true
          fi
        '') pipxTools);
    };

    # Cargo-binstall for Rust tools not in nixpkgs
    systemd.services.cargo-install-tools = {
      description = "Install Rust tools via cargo-binstall";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "neg";
      };
      script = let
        cargoTools = [
          # Rust tools not in nixpkgs
          # From Salt installers.sls cargo_pkg:
          # "aliae", "eilmeldung", "freeze", "gmap", "gowall",
          # "hxd", "lazytail", "massren", "oyo", "pup", "reddix",
          # "repeater", "resterm", "songfetch", "strace-tui",
          # "tanin", "tmmpr", "witr", "youtube-tui", "hyprscratch"
          # Many of these are now in nixpkgs; only install those that aren't
        ];
      in
        builtins.concatStringsSep "\n" (map (tool: ''
          if ! command -v "${tool}" >/dev/null 2>&1; then
            ${pkgs.cargo-binstall}/bin/cargo-binstall --no-confirm "${tool}" 2>&1 || true
          fi
        '') cargoTools);
    };
  };
}
