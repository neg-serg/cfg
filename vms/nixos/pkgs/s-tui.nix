{ lib, stdenv, fetchurl, makeWrapper, python3 }:

stdenv.mkDerivation rec {
  pname = "s-tui";
  version = "1.1.6";

  src = fetchurl {
    url = "https://github.com/amanusk/s-tui/archive/refs/tags/v${version}.tar.gz";
    hash = "sha256-maiQVnOkJ+vOT3fZTHbNWdSz8Np0wBjny0lRxyglu+c=";
  };

  dontBuild = true;

  nativeBuildInputs = [ makeWrapper ];
  
  buildInputs = [ python3 ];

  installPhase = ''
    mkdir -p $out/bin $out/share/s-tui
    cp -r . $out/share/s-tui/
    makeWrapper ${python3}/bin/python3 $out/bin/s-tui \
      --add-flags "$out/share/s-tui/s_tui/s_tui.py"
  '';

  meta = with lib; {
    description = "Stress-Terminal UI — CPU stress and monitoring tool";
    homepage = "https://github.com/amanusk/s-tui";
    license = licenses.gpl2Only;
    mainProgram = "s-tui";
    platforms = platforms.linux;
  };
}
