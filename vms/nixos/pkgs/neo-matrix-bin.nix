{ lib, stdenv, fetchurl, makeWrapper, libGL, ncurses }:

stdenv.mkDerivation rec {
  pname = "neo-matrix";
  version = "0.6.1";

  src = fetchurl {
    url = "https://github.com/st3w/neo/releases/download/v${version}/neo-${version}.tar.gz";
    hash = "sha256-pV5O1e/QpK8kjRYBinqq07YX7x06wF0pKiWKOKr0ank=";
  };

  nativeBuildInputs = [ makeWrapper ];
  buildInputs = [ libGL ncurses ];

  installPhase = ''
    mkdir -p $out/bin
    cp src/neo $out/bin/neo-matrix
    wrapProgram $out/bin/neo-matrix --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ libGL ]}
  '';

  meta = with lib; {
    description = "Simulates the digital rain from The Matrix";
    homepage = "https://github.com/st3w/neo";
    license = licenses.gpl3;
    mainProgram = "neo-matrix";
    platforms = platforms.linux;
  };
}
