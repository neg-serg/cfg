{ lib, buildGoModule, fetchFromGitHub }:

buildGoModule rec {
  pname = "duf";
  version = "0.8.1";

  src = fetchFromGitHub {
    owner = "neg-serg";
    repo = "duf";
    rev = "master";
    hash = "sha256-V+snTF7Y7dsPfn/yptCuAZ03IlVlZ7dfBW82k0CGwz4=";
  };

  vendorHash = "sha256-mCOP6R072dmJBHN8c7ae8l7yN1O25FDLIgRGUSWUn2E=";

  ldflags = [ "-s" "-w" ];

  meta = with lib; {
    description = "Disk Usage/Free Utility — forked with --style plain support";
    homepage = "https://github.com/neg-serg/duf";
    license = licenses.mit;
    mainProgram = "duf";
  };
}
