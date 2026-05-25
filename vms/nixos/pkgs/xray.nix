{ lib, stdenvNoCC, fetchurl, unzip, }:

stdenvNoCC.mkDerivation rec {
  pname = "xray";  version = "26.5.9";
  src = fetchurl {
    url = "https://github.com/XTLS/Xray-core/releases/download/v${version}/Xray-linux-64.zip";
    sha256 = "sha256-9WwQa3wBWa04a8zTQPqlu/Vf1cFYIeyeY+amuhHT0cc=";
  };
  sourceRoot = ".";  nativeBuildInputs = [ unzip ];
  installPhase = ''
    mkdir -p $out/bin $out/share/xray
    cp xray $out/bin/
    chmod +x $out/bin/xray
    # Also ship geoip/geosite data files
    [ -f geoip.dat ] && cp geoip.dat $out/share/xray/
    [ -f geosite.dat ] && cp geosite.dat $out/share/xray/
  '';
  meta = with lib; {
    description = "Xray proxy core (pre-built, with geo data)";
    homepage = "https://github.com/XTLS/Xray-core";
    license = licenses.mpl20;  platforms = [ "x86_64-linux" ];
  };
}
