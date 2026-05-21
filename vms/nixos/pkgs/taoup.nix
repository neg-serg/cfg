{ lib, stdenv, ruby, fetchFromGitHub }:

stdenv.mkDerivation rec {
  pname = "taoup";
  version = "1.1.23";

  src = fetchFromGitHub {
    owner = "globalcitizen";
    repo = "taoup";
    rev = "v${version}";
    hash = "sha256-9J46fKyeSZW71r67R8y9KVPeCH8fn27hOk/XpusqGmk=";
  };

  buildInputs = [ ruby ];

  dontBuild = true;

  installPhase = ''
    install -Dm755 taoup $out/bin/taoup
    substituteInPlace $out/bin/taoup \
      --replace-fail '/usr/bin/env ruby' '${ruby}/bin/ruby'
  '';

  meta = with lib; {
    description = "The Tao of Unix Programming";
    homepage = "https://github.com/globalcitizen/taoup";
    license = licenses.gpl3;
    mainProgram = "taoup";
    platforms = platforms.unix;
  };
}
