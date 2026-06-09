{ lib, stdenv, fetchFromGitHub, makeWrapper, ncurses }:

stdenv.mkDerivation rec {
  pname = "no-more-secrets";
  version = "1.0.1";

  src = fetchFromGitHub {
    owner = "bartobri";
    repo = "no-more-secrets";
    rev = "v${version}";
    hash = "sha256-QVCEpplsZCSQ+Fq1LBtCuPBvnzgLsmLcSrxR+e4nA5I=";
  };

  nativeBuildInputs = [ makeWrapper ];
  buildInputs = [ ncurses ];

  buildPhase = ''
    make nms
    make sneakers
  '';

  installPhase = ''
    mkdir -p $out/bin
    cp bin/nms $out/bin/
    cp bin/sneakers $out/bin/
  '';

  meta = with lib; {
    description = "Recreation of the 'decrypting text' effect from the 1992 movie Sneakers";
    homepage = "https://github.com/bartobri/no-more-secrets";
    license = licenses.gpl3;
    mainProgram = "nms";
    platforms = platforms.linux;
  };
}
