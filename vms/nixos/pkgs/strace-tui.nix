{ lib, buildGoModule, fetchFromGitHub }:

buildGoModule rec {
  pname = "strace-tui";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "neg-serg";
    repo = "strace-tui";
    rev = "main";
    hash = "";
  };

  vendorHash = "";

  meta = with lib; {
    description = "TUI frontend for strace";
    homepage = "https://github.com/neg-serg/strace-tui";
    license = licenses.mit;
    mainProgram = "strace-tui";
    platforms = platforms.linux;
  };
}
