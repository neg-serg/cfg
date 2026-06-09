{ lib, rustPlatform, fetchFromGitHub }:

rustPlatform.buildRustPackage rec {
  pname = "gitlogue";
  version = "0.9.0";

  src = fetchFromGitHub {
    owner = "unhappychoice";
    repo = "gitlogue";
    rev = "v${version}";
    hash = "sha256-w+5X3NhHCLDXRGQx2JxpIayekMk242uia1bJSRjDDAE=";
  };

  cargoHash = "sha256-Ne0dMpQJ2W/JgCXijosqXBr8B6C1XgK4KnOjByckcms=";

  meta = with lib; {
    description = "Git log viewer with rich output";
    homepage = "https://github.com/unhappychoice/gitlogue";
    license = licenses.mit;
    mainProgram = "gitlogue";
  };
}
