{ lib, buildGoModule, fetchFromGitHub }:

buildGoModule rec {
  pname = "qman";
  version = "1.5.1";

  src = fetchFromGitHub {
    owner = "plp13";
    repo = "qman";
    rev = "v${version}";
    hash = "sha256-z3ILbbwcCYZT8qabVaGnMCyZRag8djEI32i6G7cLL2A=";
  };

  vendorHash = "";

  meta = with lib; {
    description = "Quick man page viewer (TUI)";
    homepage = "https://github.com/plp13/qman";
    license = licenses.mit;
    mainProgram = "qman";
  };
}
