{ lib, stdenv, fetchurl, autoPatchelfHook, makeWrapper }:

stdenv.mkDerivation rec {
  pname = "proton-ge-custom";
  version = "9.27";

  src = fetchurl {
    url = "https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton${version}/GE-Proton${version}.tar.gz";
    hash = "sha256-as6rNd/+EwV/ItKhH+ZAh/Sc3HE4kBdgNk1EBtrk66c=";
  };

  nativeBuildInputs = [ autoPatchelfHook makeWrapper ];
  sourceRoot = ".";

  installPhase = ''
    mkdir -p $out/share/proton-ge
    cp -r . $out/share/proton-ge/
  '';

  meta = with lib; {
    description = "Custom Proton build with additional patches and fixes";
    homepage = "https://github.com/GloriousEggroll/proton-ge-custom";
    license = licenses.bsd3;
    platforms = platforms.linux;
  };
}
