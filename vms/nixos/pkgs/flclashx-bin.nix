{ lib, stdenv, fetchurl, autoPatchelfHook, makeWrapper }:

stdenv.mkDerivation rec {
  pname = "flclashx-bin";
  version = "0.1.0";

  src = fetchurl {
    url = "https://github.com/neg-serg/flclashx/releases/download/v${version}/flclashx-x86_64-unknown-linux-gnu.tar.gz";
    hash = "";
  };

  nativeBuildInputs = [ autoPatchelfHook makeWrapper ];
  sourceRoot = ".";

  installPhase = ''
    install -Dm755 flclashx $out/bin/flclashx
  '';

  meta = with lib; {
    description = "FlClashX proxy client";
    homepage = "https://github.com/neg-serg/flclashx";
    license = licenses.mit;
    mainProgram = "flclashx";
    platforms = platforms.linux;
  };
}
