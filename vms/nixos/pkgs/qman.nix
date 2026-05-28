{ lib, buildGoModule, fetchFromGitHub }:

buildGoModule rec {
  pname = "qman";
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "plp13";
    repo = "qman";
    rev = "v${version}";
    hash = "";
  };

  vendorHash = "";

  meta = with lib; {
    description = "Quick man page viewer (TUI)";
    homepage = "https://github.com/plp13/qman";
    license = licenses.mit;
    mainProgram = "qman";
  };
}
