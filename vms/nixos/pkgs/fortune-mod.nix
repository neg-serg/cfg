{ lib, stdenvNoCC, fetchurl, ... }:

stdenvNoCC.mkDerivation {
  pname = "fortune-mod";
  version = "1.4";
  src = fetchurl {
    url = "https://ftp.debian.org/debian/pool/main/f/fortune-mod/fortune-mod_1.4.orig.tar.gz";
    sha256 = "sha256-0000000000000000000000000000000000000000000000000000=";
  };
  installPhase = ''
    mkdir -p $out/bin $out/share/games/fortunes
    gcc -o $out/bin/fortune fortune.c -lresolv
    cp datfiles/* $out/share/games/fortunes/
  '';
  meta = with lib; {
    description = "Fortune cookie quotes";
    license = licenses.free;
    maintainers = [];
  };
}
