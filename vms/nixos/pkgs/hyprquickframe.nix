{ lib, stdenv, fetchurl, autoPatchelfHook, makeWrapper }:

stdenv.mkDerivation rec {
  pname = "hyprquickframe";
  version = "0.1.0";

  src = fetchurl {
    url = "https://github.com/neg-serg/hyprquickframe/releases/download/v${version}/hyprquickframe-x86_64-unknown-linux-gnu.tar.gz";
    hash = "";
  };

  nativeBuildInputs = [ autoPatchelfHook makeWrapper ];
  sourceRoot = ".";

  installPhase = ''
    install -Dm755 hyprquickframe $out/bin/hyprquickframe
  '';

  meta = with lib; {
    description = "Quick frame capture for Hyprland";
    homepage = "https://github.com/neg-serg/hyprquickframe";
    license = licenses.mit;
    mainProgram = "hyprquickframe";
    platforms = platforms.linux;
  };
}
