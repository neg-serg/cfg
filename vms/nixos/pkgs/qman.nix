{ lib, buildGoModule, fetchFromGitHub }:

buildGoModule rec {
  pname = "qman";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "neg-serg";
    repo = "qman";
    rev = "main";
    hash = "";
  };

  vendorHash = "";

  meta = with lib; {
    description = "Quick man page viewer";
    homepage = "https://github.com/neg-serg/qman";
    license = licenses.mit;
    mainProgram = "qman";
    platforms = platforms.linux;
  };
}
