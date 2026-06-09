{ lib, stdenvNoCC, fetchurl, }:

let
  # Simple geometric wallpapers fetched from images
  wallpaper = { name, sha256 }:
    fetchurl {
      url = "https://picsum.photos/seed/${name}/1920/1080";
      sha256 = sha256;
    };
in
stdenvNoCC.mkDerivation {
  pname = "neg-wallpapers";
  version = "1.0";

  srcs = [
    (fetchurl { url = "https://picsum.photos/seed/neg-bg-1/1920/1080"; sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; })
    (fetchurl { url = "https://picsum.photos/seed/neg-bg-2/1920/1080"; sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; })
    (fetchurl { url = "https://picsum.photos/seed/neg-bg-3/1920/1080"; sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; })
  ];

  unpackPhase = ''
    mkdir -p wallpapers
    for src in $srcs; do
      cp "$src" "wallpapers/$(basename $src).jpg"
    done
  '';

  installPhase = ''
    mkdir -p $out/share/wallpapers
    cp -r wallpapers/* $out/share/wallpapers/
  '';

  meta = with lib; {
    description = "Wallpapers for neg desktop";
    platforms = platforms.all;
  };
}
