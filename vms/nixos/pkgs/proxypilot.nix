{ lib, stdenv, fetchFromGitHub, fetchurl, autoPatchelfHook }:

let
  version = "0.3.0-dev-0.40";
in
stdenv.mkDerivation {
  pname = "proxypilot";
  inherit version;

  src = fetchurl {
    url = "https://github.com/Finesssee/ProxyPilot/releases/download/v${version}/proxypilot-linux-amd64";
    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };

  nativeBuildInputs = [ autoPatchelfHook ];

  dontUnpack = true;

  installPhase = ''
    install -Dm755 $src $out/bin/proxypilot
  '';

  meta = with lib; {
    description = "LLM API proxy with round-robin load balancing";
    homepage = "https://github.com/Finesssee/ProxyPilot";
    license = licenses.mit;
    mainProgram = "proxypilot";
    platforms = [ "x86_64-linux" ];
  };
}
