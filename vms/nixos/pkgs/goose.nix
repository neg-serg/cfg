{ lib, stdenvNoCC, fetchurl, autoPatchelfHook, gcc-unwrapped }:

stdenvNoCC.mkDerivation rec {
  pname = "goose";
  version = "1.35.0";

  src = fetchurl {
    url = "https://github.com/aaif-goose/goose/releases/download/v${version}/goose-x86_64-unknown-linux-gnu.tar.gz";
    sha256 = "sha256-sz9PaPC8qomPQreuVfe/eQM16VbsDsM0LF77ZsVXpAU=";
  };

  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [ gcc-unwrapped.lib ];

  sourceRoot = ".";

  installPhase = ''
    mkdir -p $out/bin
    cp goose $out/bin/goose
    chmod +x $out/bin/goose
  '';

  meta = with lib; {
    description = "Open-source, extensible AI agent that goes beyond code suggestions — install, execute, edit, and test with any LLM";
    homepage = "https://block.github.io/goose/";
    license = licenses.asl20;
    platforms = [ "x86_64-linux" ];
    mainProgram = "goose";
  };
}
