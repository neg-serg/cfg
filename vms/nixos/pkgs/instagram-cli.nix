{ lib, stdenv, fetchFromGitHub, autoPatchelfHook, makeWrapper }:

stdenv.mkDerivation rec {
  pname = "instagram-cli";
  version = "1.4.2";

  src = fetchFromGitHub {
    owner = "supreme-gg-gg";
    repo = "instagram-cli";
    rev = "v${version}";
    hash = "";
  };

  nativeBuildInputs = [ autoPatchelfHook makeWrapper ];

  installPhase = ''
    mkdir -p $out/bin
    cp instagram-cli $out/bin/ 2>/dev/null || true
  '';

  meta = with lib; {
    description = "Instagram CLI client";
    homepage = "https://github.com/supreme-gg-gg/instagram-cli";
    license = licenses.mit;
    mainProgram = "instagram-cli";
    platforms = platforms.linux;
  };
}
