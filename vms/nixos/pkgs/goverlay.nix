{ lib, stdenv, fetchurl, autoPatchelfHook, makeWrapper }:

stdenv.mkDerivation rec {
  pname = "goverlay";
  version = "1.3.0";

  src = fetchurl {
    url = "https://github.com/neg-serg/goverlay/releases/download/v${version}/goverlay-x86_64-unknown-linux-gnu.tar.gz";
    hash = "";
  };

  nativeBuildInputs = [ autoPatchelfHook makeWrapper ];
  sourceRoot = ".";

  installPhase = ''
    install -Dm755 goverlay $out/bin/goverlay
  '';

  meta = with lib; {
    description = "GUI for configuring MangoHud and vkBasalt";
    homepage = "https://github.com/neg-serg/goverlay";
    license = licenses.mit;
    mainProgram = "goverlay";
    platforms = platforms.linux;
  };
}
