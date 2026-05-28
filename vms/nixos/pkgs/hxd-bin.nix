{ lib, stdenv, fetchurl, autoPatchelfHook, makeWrapper }:

stdenv.mkDerivation rec {
  pname = "hxd-bin";
  version = "0.1.0";

  src = fetchurl {
    url = "https://github.com/neg-serg/hxd/releases/download/v${version}/hxd-x86_64-unknown-linux-gnu.tar.gz";
    hash = "";
  };

  nativeBuildInputs = [ autoPatchelfHook makeWrapper ];
  sourceRoot = ".";

  installPhase = ''
    install -Dm755 hxd $out/bin/hxd
  '';

  meta = with lib; {
    description = "Hex dump tool";
    homepage = "https://github.com/neg-serg/hxd";
    license = licenses.mit;
    mainProgram = "hxd";
    platforms = platforms.linux;
  };
}
