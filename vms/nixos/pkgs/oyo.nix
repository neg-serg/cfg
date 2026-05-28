{ lib, buildGoModule, fetchFromGitHub }:

buildGoModule rec {
  pname = "oyo";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "neg-serg";
    repo = "oyo";
    rev = "main";
    hash = "";
  };

  vendorHash = "";

  meta = with lib; {
    description = "Oyo utility tool";
    homepage = "https://github.com/neg-serg/oyo";
    license = licenses.mit;
    mainProgram = "oyo";
    platforms = platforms.linux;
  };
}
