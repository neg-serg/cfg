{ lib, stdenv, fetchurl, autoPatchelfHook, makeWrapper, pcsclite }:

stdenv.mkDerivation rec {
  pname = "yandex-browser-bin";
  version = "24.4.1";

  src = fetchurl {
    url = "https://browser.yandex.ru/download?os=linux&package=deb&full=1";
    hash = "";
  };

  nativeBuildInputs = [ autoPatchelfHook makeWrapper ];

  sourceRoot = ".";

  installPhase = ''
    mkdir -p $out/bin $out/share
    # Placeholder — actual binary extraction depends on package format
    echo "#!/bin/sh" > $out/bin/yandex-browser
    echo "echo 'Yandex Browser placeholder'" >> $out/bin/yandex-browser
    chmod +x $out/bin/yandex-browser
  '';

  meta = with lib; {
    description = "Yandex Browser — Chromium-based browser with Yandex integration";
    homepage = "https://browser.yandex.ru";
    license = licenses.unfree;
    mainProgram = "yandex-browser";
    platforms = platforms.x86_64;
  };
}
