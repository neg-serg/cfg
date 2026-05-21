{ lib, stdenv, fetchurl, unzip }:

let
  version = "1.0.13";
in
stdenv.mkDerivation {
  pname = "throne";
  inherit version;

  src = fetchurl {
    url = "https://github.com/throneproj/Throne/releases/download/v${version}/Throne-${version}-linux-amd64.zip";
    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };

  nativeBuildInputs = [ unzip ];

  sourceRoot = ".";

  installPhase = ''
    install -Dm755 Throne/Throne $out/bin/throne
  '';

  meta = with lib; {
    description = "Throne terminal tool";
    homepage = "https://github.com/throneproj/Throne";
    license = licenses.mit;
    mainProgram = "throne";
    platforms = [ "x86_64-linux" ];
  };
}
