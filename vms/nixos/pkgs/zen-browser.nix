{ lib, stdenv, fetchurl, autoPatchelfHook, makeWrapper
, alsa-lib, at-spi2-core, cairo, cups, dbus, fontconfig, freetype
, glib, gtk3, libdrm, libglvnd, libnotify, libxkbcommon, mesa
, nss, pango, pipewire, xorg
}:

let
  version = "1.11.6b";
in
stdenv.mkDerivation {
  pname = "zen-browser";
  inherit version;

  src = fetchurl {
    url = "https://github.com/zen-browser/desktop/releases/download/${version}/zen.linux-specific.tar.xz";
    hash = "sha256-0000000000000000000000000000000000000000000=";
  };

  nativeBuildInputs = [ autoPatchelfHook makeWrapper ];

  buildInputs = [
    alsa-lib at-spi2-core cairo cups dbus fontconfig freetype
    glib gtk3 libdrm libglvnd libnotify libxkbcommon mesa
    nss pango pipewire
    xorg.libX11 xorg.libXcomposite xorg.libXdamage xorg.libXext
    xorg.libXfixes xorg.libXrandr xorg.libXrender
  ];

  sourceRoot = ".";

  installPhase = ''
    mkdir -p $out/{bin,lib/zen-browser}
    cp -r ./* $out/lib/zen-browser/
    makeWrapper $out/lib/zen-browser/zen $out/bin/zen-browser \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath buildInputs} \
      --prefix PATH : ${xorg.xrandr}/bin
    ln -sf $out/bin/zen-browser $out/bin/zen
  '';

  meta = with lib; {
    description = "Firefox-based browser with a focus on privacy and customization";
    homepage = "https://zen-browser.app";
    license = licenses.mpl20;
    mainProgram = "zen-browser";
    platforms = [ "x86_64-linux" ];
  };
}
