{ lib, stdenv, fetchurl, autoPatchelfHook, makeWrapper, qt6, qt6Packages
, kdePackages, minizip, libqalculate, icu
}:

let
  version = "0.21.0";
in
stdenv.mkDerivation {
  pname = "vicinae-bin";
  inherit version;

  src = fetchurl {
    url = "https://github.com/vicinaehq/vicinae/releases/download/v${version}/vicinae-linux-x86_64-v${version}.tar.gz";
    hash = "sha256-0ZCZoJRQcYT8+TiOhe90g5qZ/DZmtBvWzDvxFuGwHKk=";
  };

  nativeBuildInputs = [ autoPatchelfHook makeWrapper qt6.wrapQtAppsHook ];

  autoPatchelfIgnoreMissingDeps = [ "libicuuc.so.78" ];

  buildInputs = with qt6; [
    qtbase
    qtdeclarative
    qtsvg
  ] ++ [
    qt6Packages.qtkeychain
    kdePackages.syntax-highlighting
    kdePackages.layer-shell-qt
    minizip
    libqalculate
    icu
  ];

  sourceRoot = ".";

  installPhase = ''
    mkdir -p $out
    cp -r ./* $out/
    wrapQtApp $out/bin/vicinae
  '';

  meta = with lib; {
    description = "Raycast-like FOSS app launcher on Linux";
    homepage = "https://github.com/vicinaehq/vicinae";
    license = licenses.gpl3;
    mainProgram = "vicinae";
    platforms = [ "x86_64-linux" ];
  };
}
