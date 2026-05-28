{ lib, stdenv, fetchurl, autoPatchelfHook, makeWrapper }:

stdenv.mkDerivation rec {
  pname = "s-tui";
  version = "1.1.6";

  src = fetchurl {
    url = "https://github.com/amanusk/s-tui/archive/refs/tags/v${version}.tar.gz";
    hash = "sha256-maiQVnOkJ+vOT3fZTHbNWdSz8Np0wBjny0lRxyglu+c=";
  };

  nativeBuildInputs = [ makeWrapper ];
  
  propagatedBuildInputs = [];

  installPhase = ''
    mkdir -p $out/bin $out/share/s-tui
    cp -r . $out/share/s-tui/
    ln -s $out/share/s-tui/s-tui $out/bin/s-tui
    chmod +x $out/share/s-tui/s-tui
  '';

  meta = with lib; {
    description = "Stress-Terminal UI — CPU stress and monitoring tool";
    homepage = "https://github.com/amanusk/s-tui";
    license = licenses.gpl2Only;
    mainProgram = "s-tui";
    platforms = platforms.linux;
  };
}
