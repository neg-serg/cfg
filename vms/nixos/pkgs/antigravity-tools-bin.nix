{ lib, stdenv, fetchurl, autoPatchelfHook, makeWrapper }:

stdenv.mkDerivation rec {
  pname = "antigravity-tools-bin";
  version = "0.1.0";

  src = fetchurl {
    url = "https://github.com/neg-serg/antigravity-tools/releases/download/v${version}/antigravity-tools-x86_64-unknown-linux-gnu.tar.gz";
    hash = "";
  };

  nativeBuildInputs = [ autoPatchelfHook makeWrapper ];
  sourceRoot = ".";

  installPhase = ''
    install -Dm755 antigravity-tools $out/bin/antigravity-tools
  '';

  meta = with lib; {
    description = "Antigravity tools collection";
    homepage = "https://github.com/neg-serg/antigravity-tools";
    license = licenses.mit;
    mainProgram = "antigravity-tools";
    platforms = platforms.linux;
  };
}
