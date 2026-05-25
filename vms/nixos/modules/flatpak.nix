{ config, pkgs, lib, ... }:

let
  cfg = config._flatpak;
  apps = [
    "com.github.qarmin.czkawka"
    "com.github.tmewett.BrogueCE"
    "com.google.Chrome"
    "com.shatteredpixel.shatteredpixeldungeon"
    "com.vysp3r.ProtonPlus"
    "io.github.dimtpap.coppwr"
    "io.github.woelper.Oculante"
    "md.obsidian.Obsidian"
    "me.timschneeberger.jdsp4linux"
    "net.davidotek.pupgui2"
    "net.lutris.Lutris"
    "net.pcsx2.PCSX2"
    "net.sapples.LiveCaptions"
    "net.veloren.airshipper"
    "org.gimp.GIMP"
    "org.zdoom.UZDoom"
    "tk.deat.Jazz2Resurrection"
  ];
in
{
  options._flatpak.enable = lib.mkEnableOption "Flatpak sandboxed apps with flathub remote";

  config = lib.mkIf cfg.enable {
    # Flatpak daemon + flathub remote (added automatically by the flatpak module)
    services.flatpak = {
      enable = true;
      uninstallUnmanaged = true;
      update.auto = {
        enable = true;
        onCalendar = "weekly";
      };
      remotes = [{
        name = "flathub";
        location = "https://flathub.org/repo/flathub.flatpakrepo";
      }];
    };

    # Install flatpak apps as user (neg)
    systemd.services.flatpak-install-apps = {
      description = "Install Flatpak applications from user list";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "neg";
      };
      script = builtins.concatStringsSep "\n" (map (app: ''
        if ! ${pkgs.flatpak}/bin/flatpak info "${app}" >/dev/null 2>&1; then
          echo "Installing flatpak: ${app}"
          ${pkgs.flatpak}/bin/flatpak install --noninteractive --assumeyes flathub "${app}" 2>&1 || echo "Warning: ${app} install failed (may require user intervention)"
        fi
      '') apps);
    };
  };
}
