{ lib, stdenv, fetchurl, autoPatchelfHook, makeWrapper }:

stdenv.mkDerivation rec {
  pname = "lazytail-bin";
  version = "0.1.0";

  src = fetchurl {
    url = "https://github.com/neg-serg/lazytail/releases/download/v${version}/lazytail-x86_64-unknown-linux-gnu.tar.gz";
    hash = "";
  };

  nativeBuildInputs = [ autoPatchelfHook makeWrapper ];
  sourceRoot = ".";

  installPhase = ''
    install -Dm755 lazytail $out/bin/lazytail
  '';

  meta = with lib; {
    description = "Lazy log tail viewer";
    homepage = "https://github.com/neg-serg/lazytail";
    license = licenses.mit;
    mainProgram = "lazytail";
    platforms = platforms.linux;
  };
}
