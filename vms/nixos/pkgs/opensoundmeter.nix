{ lib, stdenv, fetchurl, autoPatchelfHook, makeWrapper }:

stdenv.mkDerivation rec {
  pname = "opensoundmeter";
  version = "1.3.0";

  src = fetchurl {
    url = "https://github.com/neg-serg/opensoundmeter/releases/download/v${version}/opensoundmeter-x86_64-unknown-linux-gnu.tar.gz";
    hash = "";
  };

  nativeBuildInputs = [ autoPatchelfHook makeWrapper ];
  sourceRoot = ".";

  installPhase = ''
    install -Dm755 opensoundmeter $out/bin/opensoundmeter
  '';

  meta = with lib; {
    description = "Audio measurement tool";
    homepage = "https://github.com/neg-serg/opensoundmeter";
    license = licenses.mit;
    mainProgram = "opensoundmeter";
    platforms = platforms.linux;
  };
}
