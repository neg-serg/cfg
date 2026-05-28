{ lib, buildGoModule, fetchFromGitHub }:

buildGoModule rec {
  pname = "gitlogue";
  version = "0.9.0";

  src = fetchFromGitHub {
    owner = "unhappychoice";
    repo = "gitlogue";
    rev = "v${version}";
    hash = "sha256-w+5X3NhHCLDXRGQx2JxpIayekMk242uia1bJSRjDDAE=";
  };

  vendorHash = "";

  meta = with lib; {
    description = "Git log viewer with rich output";
    homepage = "https://github.com/unhappychoice/gitlogue";
    license = licenses.mit;
    mainProgram = "gitlogue";
  };
}
