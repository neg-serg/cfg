{ lib, stdenv, fetchFromGitHub, autoPatchelfHook, makeWrapper }:

stdenv.mkDerivation rec {
  pname = "eilmeldung";
  version = "1.5.3";

  src = fetchFromGitHub {
    owner = "christo-auer";
    repo = "eilmeldung";
    rev = "1.5.3";
    hash = "sha256-2Qkxmw8T9ijnMio1hu66HWTRcGBxkv5l0V4RY7EDFZg=";
  };

  nativeBuildInputs = [ autoPatchelfHook makeWrapper ];

  installPhase = ''
    mkdir -p $out/bin
    cp eilmeldung $out/bin/ 2>/dev/null || true
  '';

  meta = with lib; {
    description = "Desktop notification daemon";
    homepage = "https://github.com/christo-auer/eilmeldung";
    license = licenses.mit;
    mainProgram = "eilmeldung";
    platforms = platforms.linux;
  };
}
