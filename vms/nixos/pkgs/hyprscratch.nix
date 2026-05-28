{ lib, stdenv, fetchurl, autoPatchelfHook, makeWrapper }:

stdenv.mkDerivation rec {
  pname = "oports-git";
  version = "0.1.0";

  src = fetchurl {
    url = "https://github.com/neg-serg/oports/releases/download/v${version}/oports-x86_64-unknown-linux-gnu.tar.gz";
    hash = "";
  };

  nativeBuildInputs = [ autoPatchelfHook makeWrapper ];
  sourceRoot = ".";

  installPhase = ''
    install -Dm755 oports $out/bin/oports
  '';

  meta = with lib; {
    description = "Open port scanner";
    homepage = "https://github.com/neg-serg/oports";
    license = licenses.mit;
    mainProgram = "oports";
    platforms = platforms.linux;
  };
}
