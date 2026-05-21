{ lib, buildGoModule, fetchFromGitHub }:

buildGoModule rec {
  pname = "duf";
  version = "0.8.1";

  src = fetchFromGitHub {
    owner = "neg-serg";
    repo = "duf";
    rev = "master";
    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };

  vendorHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";

  ldflags = [ "-s" "-w" ];

  meta = with lib; {
    description = "Disk Usage/Free Utility — forked with --style plain support";
    homepage = "https://github.com/neg-serg/duf";
    license = licenses.mit;
    mainProgram = "duf";
  };
}
