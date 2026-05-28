{ lib, stdenv, fetchurl, autoPatchelfHook, makeWrapper }:

stdenv.mkDerivation rec {
  pname = "droidcam";
  version = "2.1.3";

  src = fetchurl {
    url = "https://github.com/dev47apps/droidcam/releases/download/v${version}/droidcam_${version}.zip";
    hash = "sha256-5IwUXE/tWIOIPI3ruSBkskZ57ybFkFQn1YEZqmyeWP4=";
  };

  nativeBuildInputs = [ autoPatchelfHook makeWrapper unzip ];
  sourceRoot = ".";

  installPhase = ''
    install -Dm755 droidcam $out/bin/droidcam
    install -Dm755 droidcam-cli $out/bin/droidcam-cli
  '';

  meta = with lib; {
    description = "Use your Android phone as a webcam";
    homepage = "https://www.dev47apps.com";
    license = licenses.gpl2Only;
    mainProgram = "droidcam";
    platforms = platforms.linux;
  };
}
