{ lib, stdenv, fetchurl, autoPatchelfHook, makeWrapper }:

stdenv.mkDerivation rec {
  pname = "eilmeldung-bin";
  version = "0.1.0";

  src = fetchurl {
    url = "https://github.com/neg-serg/eilmeldung/releases/download/v${version}/eilmeldung-x86_64-unknown-linux-gnu.tar.gz";
    hash = "";
  };

  nativeBuildInputs = [ autoPatchelfHook makeWrapper ];
  sourceRoot = ".";

  installPhase = ''
    install -Dm755 eilmeldung $out/bin/eilmeldung
  '';

  meta = with lib; {
    description = "Eilmeldung notification tool";
    homepage = "https://github.com/neg-serg/eilmeldung";
    license = licenses.mit;
    mainProgram = "eilmeldung";
    platforms = platforms.linux;
  };
}
