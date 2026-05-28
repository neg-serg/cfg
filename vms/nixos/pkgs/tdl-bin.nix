{ lib, stdenv, fetchurl, autoPatchelfHook, makeWrapper }:

stdenv.mkDerivation rec {
  pname = "tdl-bin";
  version = "0.18.0";

  src = fetchurl {
    url = "https://github.com/iyear/tdl/releases/download/v${version}/tdl_Linux_x86_64.tar.gz";
    hash = "";
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
