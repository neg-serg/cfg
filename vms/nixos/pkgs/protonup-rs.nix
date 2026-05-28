{ lib, stdenv, fetchurl, autoPatchelfHook, makeWrapper }:

stdenv.mkDerivation rec {
  pname = "protonup-rs";
  version = "0.1.0";

  src = fetchurl {
    url = "https://github.com/neg-serg/protonup-rs/releases/download/v${version}/protonup-rs-x86_64-unknown-linux-gnu.tar.gz";
    hash = "";
  };

  nativeBuildInputs = [ autoPatchelfHook makeWrapper ];
  sourceRoot = ".";

  installPhase = ''
    install -Dm755 protonup-rs $out/bin/protonup-rs
  '';

  meta = with lib; {
    description = "Proton-GE installer for Steam (Rust)";
    homepage = "https://github.com/neg-serg/protonup-rs";
    license = licenses.mit;
    mainProgram = "protonup-rs";
    platforms = platforms.linux;
  };
}
