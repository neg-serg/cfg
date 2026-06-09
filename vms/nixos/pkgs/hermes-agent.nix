{ lib, stdenvNoCC, fetchurl, }:

stdenvNoCC.mkDerivation rec {
  pname = "hermes-agent";  version = "0.10.4";
  src = fetchurl {
    url = "https://github.com/NousResearch/hermes-agent/releases/download/v${version}/hermes-agent-x86_64-unknown-linux-musl.tar.gz";
    sha256 = "sha256-ABnfxLMtY8E5KqJkrtIlPB4ML7CSFvjizCabv7i7SbU=";
  };
  sourceRoot = ".";
  installPhase = ''
    mkdir -p $out/bin
    [ -f hermes-agent ] && cp hermes-agent $out/bin/ || cp hermes $out/bin/hermes-agent 2>/dev/null || true
    chmod +x $out/bin/hermes-agent 2>/dev/null || true
  '';
  meta = with lib; {
    description = "Hermes AI agent (Nous Research, CLI)";
    homepage = "https://github.com/NousResearch/hermes-agent";
    license = licenses.asl20;  platforms = [ "x86_64-linux" ];
  };
}
