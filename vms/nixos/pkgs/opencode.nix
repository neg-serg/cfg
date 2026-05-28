{ lib, stdenv, fetchFromGitHub, autoPatchelfHook, makeWrapper }:

stdenv.mkDerivation rec {
  pname = "opencode";
  version = "1.15.7";

  src = fetchFromGitHub {
    owner = "anomalyco";
    repo = "opencode";
    rev = "v${version}";
    hash = "sha256-fk8GDVE+bQfOkZCQ1YEc3V7YIXDHfNC/srcZs/MrE38=";
  };

  nativeBuildInputs = [ autoPatchelfHook makeWrapper ];

  installPhase = ''
    mkdir -p $out/bin
    cp opencode $out/bin/ 2>/dev/null || cp target/release/opencode $out/bin/ 2>/dev/null || true
  '';

  meta = with lib; {
    description = "The open source coding agent";
    homepage = "https://github.com/anomalyco/opencode";
    license = licenses.mit;
    mainProgram = "opencode";
    platforms = platforms.linux;
  };
}
