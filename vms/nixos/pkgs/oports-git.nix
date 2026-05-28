{ lib, buildGoModule, fetchFromGitHub }:

buildGoModule rec {
  pname = "oports";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "sdushantha";
    repo = "oports";
    rev = "a454b10";  # r10.a454b10
    hash = "";
  };

  vendorHash = "";

  meta = with lib; {
    description = "List open ports";
    homepage = "https://github.com/sdushantha/oports";
    license = licenses.mit;
    mainProgram = "oports";
  };
}
