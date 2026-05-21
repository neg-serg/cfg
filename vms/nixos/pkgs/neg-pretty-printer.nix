{ lib, python3 }:

python3.pkgs.buildPythonPackage rec {
  pname = "neg-pretty-printer";
  version = "0.1.0";

  # Source is local repo directory
  src = ../../../pretty-printer;

  format = "pyproject";

  propagatedBuildInputs = with python3.pkgs; [ colored ];

  meta = with lib; {
    description = "Custom pretty-printer for Python debugging";
    homepage = "https://github.com/neg-serg";
    license = licenses.mit;
  };
}
