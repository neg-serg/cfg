{ lib, stdenv, fetchFromGitHub, autoPatchelfHook, makeWrapper }:

stdenv.mkDerivation rec {
  pname = "cloudflare-speedtest";
  version = "0.6.13";

  src = fetchFromGitHub {
    owner = "kavehtehrani";
    repo = "cloudflare-speed-cli";
    rev = "v${version}";
    hash = "sha256-ye2/r5/NN/pU5JchI4KYH/sB8iLU0FIhxPKcGqwqv7E=";
  };

  nativeBuildInputs = [ autoPatchelfHook makeWrapper ];

  installPhase = ''
    mkdir -p $out/bin
    cp cloudflare-speedtest $out/bin/ 2>/dev/null || true
  '';

  meta = with lib; {
    description = "Cloudflare speed test CLI";
    homepage = "https://github.com/kavehtehrani/cloudflare-speed-cli";
    license = licenses.mit;
    mainProgram = "cloudflare-speedtest";
    platforms = platforms.linux;
  };
}
