{ lib, stdenv, fetchurl, autoPatchelfHook, makeWrapper }:

stdenv.mkDerivation rec {
  pname = "aliae-bin";
  version = "0.19.0";

  src = fetchurl {
    url = "https://github.com/aliae/aliae/releases/download/v${version}/aliae-x86_64-unknown-linux-gnu.tar.gz";
    hash = "";  # Fill after first build attempt
  };

  nativeBuildInputs = [ autoPatchelfHook makeWrapper ];
  buildInputs = [];

  sourceRoot = ".";

  installPhase = ''
    install -Dm755 aliae $out/bin/aliae
    wrapProgram $out/bin/aliae --prefix PATH : ${lib.makeBinPath []}
  '';

  meta = with lib; {
    description = "Cross-shell aliases manager";
    homepage = "https://github.com/aliae/aliae";
    license = licenses.mit;
    mainProgram = "aliae";
    platforms = platforms.linux;
  };
}
