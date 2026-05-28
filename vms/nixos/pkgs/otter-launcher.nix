{ lib, buildGoModule, fetchFromGitHub }:

buildGoModule rec {
  pname = "otter-launcher";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "neg-serg";
    repo = "otter-launcher";
    rev = "main";
    hash = "";
  };

  vendorHash = "";

  meta = with lib; {
    description = "Otter application launcher";
    homepage = "https://github.com/neg-serg/otter-launcher";
    license = licenses.mit;
    mainProgram = "otter-launcher";
    platforms = platforms.linux;
  };
}
