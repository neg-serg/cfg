{ lib, stdenv, fetchurl, autoPatchelfHook, makeWrapper }:

stdenv.mkDerivation rec {
  pname = "tdl-bin";
  version = "0.20.3";

  src = fetchurl {
    url = "https://github.com/iyear/tdl/releases/download/v${version}/tdl_Linux_64bit.tar.gz";
    hash = "";  # FIXME: nix-prefetch-url to fill
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
