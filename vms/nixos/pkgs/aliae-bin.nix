{ lib, stdenv, fetchFromGitHub }:

stdenv.mkDerivation rec {
  pname = "aliae";
  version = "0.26.6";

  src = fetchFromGitHub {
    owner = "aliae";
    repo = "aliae";
    rev = "v${version}";
    hash = "";
  };

  installPhase = ''
    mkdir -p $out/bin
    cp aliae $out/bin/ 2>/dev/null || cp target/release/aliae $out/bin/
  '';

  meta = with lib; {
    description = "Cross shell aliases manager";
    homepage = "https://aliae.dev";
    license = licenses.mit;
    mainProgram = "aliae";
    platforms = platforms.linux;
  };
}
