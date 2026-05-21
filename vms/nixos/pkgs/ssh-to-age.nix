{ lib, stdenv, fetchurl, autoPatchelfHook }:

let
  version = "1.2.0";
in
stdenv.mkDerivation {
  pname = "ssh-to-age";
  inherit version;

  src = fetchurl {
    url = "https://github.com/Mic92/ssh-to-age/releases/download/${version}/ssh-to-age.linux-amd64";
    hash = "sha256-mYCpsZyUldRG6CWiY5t3yzgdswcQ1QVCyDW4bp76+Ok=";
  };

  nativeBuildInputs = [ autoPatchelfHook ];

  dontUnpack = true;

  installPhase = ''
    install -Dm755 $src $out/bin/ssh-to-age
  '';

  meta = with lib; {
    description = "Convert SSH Ed25519 keys to age keys";
    homepage = "https://github.com/Mic92/ssh-to-age";
    license = licenses.mit;
    mainProgram = "ssh-to-age";
    platforms = [ "x86_64-linux" ];
  };
}
