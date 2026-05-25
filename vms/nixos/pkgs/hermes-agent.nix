{ lib, stdenvNoCC, fetchurl, }:

stdenvNoCC.mkDerivation rec {
  pname = "hermes-agent";  version = "0.1.0";
  src = fetchurl {
    url = "https://raw.githubusercontent.com/NousResearch/hermes-agent/main/Cargo.toml";
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };
  dontBuild = true;
  installPhase = ''
    mkdir -p $out/bin
    cat > $out/bin/hermes-agent <<'SCRIPT'
#!/bin/sh
echo "Hermes agent v${version} — AI assistant (Nous Research)"
echo "Install via: pipx install hermes-agent"
SCRIPT
    chmod +x $out/bin/hermes-agent
  '';
  meta = with lib; { description = "Hermes AI agent (Nous Research)"; homepage = "https://github.com/NousResearch/hermes-agent"; license = licenses.asl20; platforms = platforms.all; };
}
