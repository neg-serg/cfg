{ lib, rustPlatform, fetchFromGitHub }:

rustPlatform.buildRustPackage rec {
  pname = "raise";
  version = "0.2.0";

  src = fetchFromGitHub {
    owner = "neg-serg";
    repo = "raise";
    rev = "master";
    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };

  cargoHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";

  meta = with lib; {
    description = "Custom utility";
    homepage = "https://github.com/neg-serg/raise";
    license = licenses.mit;
    mainProgram = "raise";
  };
}
