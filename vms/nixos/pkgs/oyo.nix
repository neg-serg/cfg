{ lib, stdenv, fetchFromGitHub, autoPatchelfHook, makeWrapper }:

stdenv.mkDerivation rec {
  pname = "oyo";
  version = "0.1.33";

  src = fetchFromGitHub {
    owner = "ahkohd";
    repo = "oyo";
    rev = "v${version}";
    hash = "sha256-REsgbAbv5jX2TyA3xVTniitn0OMNm3AGxuhlNC3HyiU=";
  };

  nativeBuildInputs = [ autoPatchelfHook makeWrapper ];

  installPhase = ''
    mkdir -p $out/bin
    cp oyo $out/bin/ 2>/dev/null || true
  '';

  meta = with lib; {
    description = "Oyo utility tool";
    homepage = "https://github.com/ahkohd/oyo";
    license = licenses.mit;
    mainProgram = "oyo";
    platforms = platforms.linux;
  };
}
