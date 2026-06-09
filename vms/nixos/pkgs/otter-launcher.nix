{ lib, stdenv, fetchFromGitHub, autoPatchelfHook, makeWrapper }:

stdenv.mkDerivation rec {
  pname = "otter-launcher";
  version = "0.7.4";

  src = fetchFromGitHub {
    owner = "kuokuo123";
    repo = "otter-launcher";
    rev = "v${version}";
    hash = "sha256-TGbz1FU7oZetH0bUeowrsueXodTEyKs3iaiXniOBesk=";
  };

  nativeBuildInputs = [ autoPatchelfHook makeWrapper ];

  installPhase = ''
    mkdir -p $out/bin
    cp otter-launcher $out/bin/ 2>/dev/null || true
  '';

  meta = with lib; {
    description = "Otter application launcher";
    homepage = "https://github.com/kuokuo123/otter-launcher";
    license = licenses.mit;
    mainProgram = "otter-launcher";
    platforms = platforms.linux;
  };
}
