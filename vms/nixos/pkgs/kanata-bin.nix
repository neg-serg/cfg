{ lib, stdenv, fetchurl, autoPatchelfHook, makeWrapper }:

stdenv.mkDerivation rec {
  pname = "kanata-bin";
  version = "1.7.0";

  src = fetchurl {
    url = "https://github.com/jtroo/kanata/releases/download/v${version}/kanata";
    hash = "";
  };

  dontUnpack = true;

  nativeBuildInputs = [ autoPatchelfHook makeWrapper ];

  installPhase = ''
    install -Dm755 $src $out/bin/kanata
  '';

  meta = with lib; {
    description = "Software keyboard remapper for Linux";
    homepage = "https://github.com/jtroo/kanata";
    license = licenses.lgpl3Only;
    mainProgram = "kanata";
    platforms = platforms.linux;
  };
}
