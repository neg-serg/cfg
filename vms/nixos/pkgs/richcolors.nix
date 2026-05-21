{ lib, python3, fetchFromGitHub }:

python3.pkgs.buildPythonApplication {
  pname = "richcolors";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "Rizen54";
    repo = "richcolors";
    rev = "main";
    hash = "sha256-lzqNDnMFVGgXlshq20Uca86ctRn1p6VFsAc0QCe7fnU=";
  };

  format = "other";

  propagatedBuildInputs = with python3.pkgs; [ pillow ];

  installPhase = ''
    install -Dm755 richcolors $out/bin/richcolors
  '';

  meta = with lib; {
    description = "Rich text color preview tool";
    homepage = "https://github.com/Rizen54/richcolors";
    license = licenses.mit;
    mainProgram = "richcolors";
  };
}
