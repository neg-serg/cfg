{ lib, stdenv, fetchFromGitHub, autoPatchelfHook, makeWrapper }:

stdenv.mkDerivation rec {
  pname = "strace-tui";
  version = "1.0.1";

  src = fetchFromGitHub {
    owner = "Rodrigodd";
    repo = "strace-tui";
    rev = "v${version}";
    hash = "";
  };

  nativeBuildInputs = [ autoPatchelfHook makeWrapper ];

  installPhase = ''
    mkdir -p $out/bin
    cp strace-tui $out/bin/ 2>/dev/null || true
  '';

  meta = with lib; {
    description = "TUI frontend for strace";
    homepage = "https://github.com/Rodrigodd/strace-tui";
    license = licenses.mit;
    mainProgram = "strace-tui";
    platforms = platforms.linux;
  };
}
