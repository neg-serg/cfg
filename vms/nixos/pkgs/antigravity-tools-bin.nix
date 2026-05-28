{ lib, stdenv, fetchFromGitHub, autoPatchelfHook, makeWrapper }:

stdenv.mkDerivation rec {
  pname = "antigravity-tools";
  version = "4.2.1";

  src = fetchFromGitHub {
    owner = "lbjlaq";
    repo = "Antigravity-Manager";
    rev = "v${version}";
    hash = "";
  };

  nativeBuildInputs = [ autoPatchelfHook makeWrapper ];

  installPhase = ''
    mkdir -p $out/bin
    cp antigravity-tools $out/bin/ 2>/dev/null || true
  '';

  meta = with lib; {
    description = "Antigravity tools manager";
    homepage = "https://github.com/lbjlaq/Antigravity-Manager";
    license = licenses.mit;
    mainProgram = "antigravity-tools";
    platforms = platforms.linux;
  };
}
