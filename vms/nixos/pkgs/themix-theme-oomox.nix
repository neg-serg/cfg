{ lib, stdenvNoCC, fetchFromGitHub, gtk3, glib, gdk-pixbuf, sassc, librsvg, bash }:

stdenvNoCC.mkDerivation rec {
  pname = "themix-theme-oomox";
  version = "1.15.1";

  src = fetchFromGitHub {
    owner = "themix-project";
    repo = "oomox-gtk-theme";
    rev = "0f134c33";
    sha256 = "sha256-0000000000000000000000000000000000000000000=";
  };

  buildInputs = [ gtk3 glib gdk-pixbuf sassc librsvg bash ];

  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    plugin_dir=$out/opt/oomox/plugins/theme_oomox
    mkdir -p $plugin_dir
    cp -r ./* $plugin_dir/

    mkdir -p $out/bin
    cat > $out/bin/oomox-cli << 'WRAPPER'
#!/bin/sh
cd $out/opt/oomox/plugins/theme_oomox && exec ./change_color.sh "$@"
WRAPPER
    chmod +x $out/bin/oomox-cli

    # Fix shebangs
    patchShebangs $plugin_dir
  '';

  meta = with lib; {
    description = "Oomox GTK theme generator plugin for Themix";
    homepage = "https://github.com/themix-project/oomox-gtk-theme";
    license = licenses.gpl3Plus;
    platforms = platforms.linux;
    mainProgram = "oomox-cli";
  };
}
