{ lib, stdenv, fetchFromGitHub, autoPatchelfHook, makeWrapper }:

stdenv.mkDerivation rec {
  pname = "pipemixer";
  version = "0.5.1";

  src = fetchFromGitHub {
    owner = "heather7283";
    repo = "pipemixer";
    rev = "v${version}";
    hash = "sha256-dVw8x9c3DFSL5eLbBOe7ExNzeKsj3xB5Spl516XFqTQ=";
  };

  nativeBuildInputs = [ autoPatchelfHook makeWrapper ];

  installPhase = ''
    mkdir -p $out/bin
    cp pipemixer $out/bin/ 2>/dev/null || true
  '';

  meta = with lib; {
    description = "PipeWire audio mixer";
    homepage = "https://github.com/heather7283/pipemixer";
    license = licenses.mit;
    mainProgram = "pipemixer";
    platforms = platforms.linux;
  };
}
