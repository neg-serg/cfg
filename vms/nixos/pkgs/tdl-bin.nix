{ lib, stdenv, fetchurl, autoPatchelfHook, makeWrapper }:

stdenv.mkDerivation rec {
  pname = "tdl-bin";
  version = "0.20.3";

  src = fetchurl {
    url = "https://github.com/iyear/tdl/releases/download/v${version}/tdl_Linux_64bit.tar.gz";
    hash = "sha256-9p/gbBf3TDCjuJS1vgXFehsIL1azRsmUAlojAbJppxg=";
  };

  nativeBuildInputs = [ autoPatchelfHook makeWrapper ];
  sourceRoot = ".";

  installPhase = ''
    install -Dm755 tdl $out/bin/tdl
  '';

  meta = with lib; {
    description = "Telegram downloader and uploader";
    homepage = "https://github.com/iyear/tdl";
    license = licenses.agpl3Only;
    mainProgram = "tdl";
    platforms = platforms.linux;
  };
}
