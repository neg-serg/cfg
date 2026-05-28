{ lib, buildGoModule, fetchFromGitHub }:

buildGoModule rec {
  pname = "gitlogue";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "neg-serg";
    repo = "gitlogue";
    rev = "main";
    hash = "";
  };

  vendorHash = "";

  meta = with lib; {
    description = "Git history analysis tool";
    homepage = "https://github.com/neg-serg/gitlogue";
    license = licenses.mit;
    mainProgram = "gitlogue";
    platforms = platforms.linux;
  };
}
