{ lib, stdenv, fetchurl, autoPatchelfHook, makeWrapper }:

stdenv.mkDerivation rec {
  pname = "s-tui";
  version = "1.1.6";

  src = fetchurl {
    url = "https://github.com/amanusk/s-tui/releases/download/v${version}/s-tui-${version}.tar.gz";
    hash = "";
  };

  nativeBuildInputs = [ makeWrapper ];
  
  propagatedBuildInputs = [];

  installPhase = ''
    mkdir -p $out/bin
    cp -r . $out/share/s-tui
    makeWrapper ${"${out}/share/s-tui/s-tui"} $out/bin/s-tui
  '';

  meta = with lib; {
    description = "Stress-Terminal UI — CPU stress and monitoring tool";
    homepage = "https://github.com/amanusk/s-tui";
    license = licenses.gpl2Only;
    mainProgram = "s-tui";
    platforms = platforms.linux;
  };
}
