{ lib, stdenv, fetchFromGitHub, autoPatchelfHook, makeWrapper }:

stdenv.mkDerivation rec {
  pname = "protonup-rs";
  version = "0.12.1";

  src = fetchFromGitHub {
    owner = "auyer";
    repo = "Protonup-rs";
    rev = "v${version}";
    hash = "sha256-ODoVlYTYfxAOBfIMoQuXJMyisBSSKijuuctXacAK3jg=";
  };

  nativeBuildInputs = [ autoPatchelfHook makeWrapper ];

  installPhase = ''
    mkdir -p $out/bin
    cp protonup-rs $out/bin/ 2>/dev/null || true
  '';

  meta = with lib; {
    description = "Proton-GE installer written in Rust";
    homepage = "https://github.com/auyer/Protonup-rs";
    license = licenses.gpl3;
    mainProgram = "protonup-rs";
    platforms = platforms.linux;
  };
}
