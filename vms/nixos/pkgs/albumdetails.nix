{ lib, stdenv, fetchFromGitHub, taglib }:

stdenv.mkDerivation rec {
  pname = "albumdetails";
  version = "0.1";

  src = fetchFromGitHub {
    owner = "neg-serg";
    repo = "albumdetails";
    rev = "master";
    hash = "sha256-9iaSyNqc/hXKc4iiDB6C7+2CMvKLWCRycsv6qVBD4wk=";
  };

  buildInputs = [ taglib ];

  makeFlags = [ "PREFIX=${placeholder "out"}" ];

  meta = with lib; {
    description = "Music metadata tool";
    homepage = "https://github.com/neg-serg/albumdetails";
    license = licenses.mit;
    mainProgram = "albumdetails";
    platforms = platforms.unix;
  };
}
