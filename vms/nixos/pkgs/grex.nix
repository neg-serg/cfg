{ lib, buildGoModule, fetchFromGitHub }:

buildGoModule rec {
  pname = "grex";
  version = "1.4.5";

  src = fetchFromGitHub {
    owner = "pemistahl";
    repo = "grex";
    rev = "v${version}";
    hash = "";
  };

  vendorHash = "";

  meta = with lib; {
    description = "Command-line tool for generating regular expressions from user-provided test cases";
    homepage = "https://github.com/pemistahl/grex";
    license = licenses.asl20;
    mainProgram = "grex";
  };
}
