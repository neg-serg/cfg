{ lib, stdenv, fetchFromGitHub, autoPatchelfHook, makeWrapper }:

stdenv.mkDerivation rec {
  pname = "lazytail";
  version = "0.10.0";

  src = fetchFromGitHub {
    owner = "raaymax";
    repo = "lazytail";
    rev = "v${version}";
    hash = "sha256-BjQ7YkGttRK5EhApoJXw3FDNyH9okD721ZmW4T2U07U=";
  };

  nativeBuildInputs = [ autoPatchelfHook makeWrapper ];

  installPhase = ''
    mkdir -p $out/bin
    cp lazytail $out/bin/ 2>/dev/null || true
  '';

  meta = with lib; {
    description = "Drop-in replacement for tail -f with extra features";
    homepage = "https://github.com/raaymax/lazytail";
    license = licenses.mit;
    mainProgram = "lazytail";
    platforms = platforms.linux;
  };
}
