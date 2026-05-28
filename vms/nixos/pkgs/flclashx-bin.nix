{ lib, stdenv, fetchFromGitHub, autoPatchelfHook, makeWrapper }:

stdenv.mkDerivation rec {
  pname = "flclashx";
  version = "0.3.2";

  src = fetchFromGitHub {
    owner = "pluralplay";
    repo = "FlClashX";
    rev = "v${version}";
    hash = "";
  };

  nativeBuildInputs = [ autoPatchelfHook makeWrapper ];

  installPhase = ''
    mkdir -p $out/bin
    cp flclashx $out/bin/ 2>/dev/null || true
  '';

  meta = with lib; {
    description = "Clash proxy client GUI";
    homepage = "https://github.com/pluralplay/FlClashX";
    license = licenses.mit;
    mainProgram = "flclashx";
    platforms = platforms.linux;
  };
}
