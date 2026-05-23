{ lib, stdenv, fetchurl, autoPatchelfHook, makeWrapper
, qt6, qt6Packages
}:

let
  version = "0.21.0";
in
stdenv.mkDerivation {
  pname = "vicinae-bin";
  inherit version;

  src = fetchurl {
    url = "https://github.com/vicinaehq/vicinae/releases/download/v${version}/vicinae-x86_64-v${version}.tgz";
    hash = "sha256-0000000000000000000000000000000000000000000=";
  };

  nativeBuildInputs = [ autoPatchelfHook makeWrapper ];

  buildInputs = with qt6; [
    qtbase
    qtdeclarative
    qtsvg
  ] ++ [
    qt6Packages.qtkeychain
  ];

  sourceRoot = ".";

  installPhase = ''
    mkdir -p $out/bin
    cp -r usr/* $out/
    wrapProgram $out/bin/vicinae \
      --prefix LD_LIBRARY_PATH : ${qt6.qtbase}/lib:${qt6.qtdeclarative}/lib:${qt6.qtsvg}/lib
  '';

  meta = with lib; {
    description = "Raycast-like FOSS app launcher on Linux";
    homepage = "https://github.com/vicinaehq/vicinae";
    license = licenses.gpl3;
    mainProgram = "vicinae";
    platforms = [ "x86_64-linux" ];
  };
}
