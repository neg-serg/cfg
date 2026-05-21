{ lib, stdenv, fetchurl, autoPatchelfHook }:

let
  version = "0.77.0";
in
stdenv.mkDerivation {
  pname = "sidecar";
  inherit version;

  src = fetchurl {
    url = "https://github.com/marcus/sidecar/releases/download/v${version}/sidecar_${version}_linux_amd64.tar.gz";
    hash = "sha256-PXXRlHaresWxWgrDv1XUST7/DWEINAoGJotwp+mqJrQ=";
  };

  nativeBuildInputs = [ autoPatchelfHook ];

  sourceRoot = ".";

  installPhase = ''
    install -Dm755 sidecar $out/bin/sidecar
  '';

  meta = with lib; {
    description = "CLI tool manager";
    homepage = "https://github.com/marcus/sidecar";
    license = licenses.mit;
    mainProgram = "sidecar";
    platforms = [ "x86_64-linux" ];
  };
}
