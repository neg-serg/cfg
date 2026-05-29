{ lib, rustPlatform, fetchFromGitHub }:

rustPlatform.buildRustPackage rec {
  pname = "aliae";
  version = "0.26.6";

  src = fetchFromGitHub {
    owner = "aliae";
    repo = "aliae";
    rev = "v${version}";
    hash = "";
  };

  cargoHash = "";

  meta = with lib; {
    description = "Cross-shell aliases manager";
    homepage = "https://aliae.dev";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
