{
  lib,
  stdenvNoCC,
  fetchurl,
  ...
}:

stdenvNoCC.mkDerivation rec {
  pname = "rofi-calc";
  version = "2.4.0";

  src = fetchurl {
    url = "https://github.com/svenstaro/rofi-calc/releases/download/v${version}/rofi-calc";
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };

  dontUnpack = true;

  installPhase = ''
    install -Dm755 $src $out/bin/rofi-calc
  '';

  meta = with lib; {
    description = "Rofi calculator plugin (rofi-calc)";
    homepage = "https://github.com/svenstaro/rofi-calc";
    license = licenses.mit;
    maintainers = [];
    platforms = platforms.linux;
  };
}
