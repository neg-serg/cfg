{ lib, stdenv, fetchurl, autoPatchelfHook, makeWrapper, libGL }:

stdenv.mkDerivation rec {
  pname = "neo-matrix-bin";
  version = "0.6.1";

  src = fetchurl {
    url = "https://github.com/st3w/neo/releases/download/v${version}/neo-matrix-linux-x86_64.tar.gz";
    hash = "";
  };

  nativeBuildInputs = [ autoPatchelfHook makeWrapper ];
  buildInputs = [ libGL ];

  sourceRoot = ".";

  installPhase = ''
    install -Dm755 neo-matrix $out/bin/neo-matrix
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
