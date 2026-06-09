{ lib, stdenvNoCC, fetchurl, fortune-mod, python3, ... }:

stdenvNoCC.mkDerivation {
  pname = "geoip-database";
  version = "2025-01";

  src = fetchurl {
    url = "https://raw.githubusercontent.com/neg/geoip-mirror/main/GeoLite2-Country.mmdb";
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };

  dontUnpack = true;

  installPhase = ''
    mkdir -p $out/share/GeoIP
    cp $src $out/share/GeoIP/GeoLite2-Country.mmdb
  '';

  meta = with lib; {
    description = "GeoIP country database for geolocation";
    license = licenses.unfree;
    maintainers = [];
    platforms = platforms.all;
  };
}
