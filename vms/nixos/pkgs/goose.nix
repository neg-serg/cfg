{
  lib, stdenvNoCC, fetchurl, autoPatchelfHook,
}:

stdenvNoCC.mkDerivation rec {
  pname = "goose";
  version = "1.35.0";

  src = fetchurl {
    url = "https://github.com/aaif-goose/goose/releases/download/v${version}/goose-x86_64-unknown-linux-gnu.tar.gz";
    sha256 = "sha256-BYYTxCFZDS4D7ODjVE3i1SgG/rAMHAChACHBeXGpwN4=";
  };

  nativeBuildInputs = [ autoPatchelfHook ];

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
