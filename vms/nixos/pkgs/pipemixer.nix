{ lib, buildGoModule, fetchFromGitHub }:

buildGoModule rec {
  pname = "pipemixer";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "neg-serg";
    repo = "pipemixer";
    rev = "main";
    hash = "";
  };

  vendorHash = "";

  meta = with lib; {
    description = "PipeWire audio mixer";
    homepage = "https://github.com/neg-serg/pipemixer";
    license = licenses.mit;
    mainProgram = "pipemixer";
    platforms = platforms.linux;
  };
}
