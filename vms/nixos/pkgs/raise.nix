{ lib, rustPlatform, fetchFromGitHub }:

rustPlatform.buildRustPackage rec {
  pname = "raise";
  version = "0.2.0";

  src = fetchFromGitHub {
    owner = "neg-serg";
    repo = "raise";
    rev = "master";
    hash = "sha256-D50/N1kcysjr8Tx7FfXR1L0OP+DiqdLjS54+/ptp37I=";
  };

  cargoHash = "sha256-dTuF6yXRJiLeKQEhmcBE5RCFFBS35JTwl91ztP8/MF4=";

  meta = with lib; {
    description = "Custom utility";
    homepage = "https://github.com/neg-serg/raise";
    license = licenses.mit;
    mainProgram = "raise";
  };
}
