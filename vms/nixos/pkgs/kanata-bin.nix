{ lib, stdenv, fetchurl, autoPatchelfHook, makeWrapper }:
stdenv.mkDerivation rec {
  pname = "kanata-bin"; version = "1.7.0";
  src = fetchurl {
    url = "https://github.com/jtroo/kanata/releases/download/v${version}/kanata";
    hash = "sha256-A/LciI/Hgx1Q9V/B/13LH8EBVhaoVSnLuTbDu8SvEyY=";
  };
  nativeBuildInputs = [ autoPatchelfHook makeWrapper ];
  buildInputs = [ stdenv.cc.cc.lib ];
  dontUnpack = true;
  installPhase = ''
    install -Dm755 $src $out/bin/kanata
  '';
  meta = with lib; { license = licenses.lgpl3Only; platforms = [ "x86_64-linux" ]; };
}
