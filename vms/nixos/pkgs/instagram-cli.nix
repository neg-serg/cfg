{ lib, python3Packages, fetchFromGitHub }:

python3Packages.buildPythonApplication rec {
  pname = "instagram-cli";
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "neg-serg";
    repo = "instagram-cli";
    rev = "main";
    hash = "";
  };

  propagatedBuildInputs = with python3Packages; [ requests ];

  meta = with lib; {
    description = "Instagram CLI tool";
    homepage = "https://github.com/neg-serg/instagram-cli";
    license = licenses.mit;
    mainProgram = "instagram-cli";
    platforms = platforms.linux;
  };
}
