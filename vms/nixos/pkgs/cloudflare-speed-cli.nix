{ lib, stdenv, fetchurl, autoPatchelfHook, makeWrapper }:

stdenv.mkDerivation rec {
  pname = "cloudflare-speedtest";
  version = "2.2.5";

  src = fetchurl {
    url = "https://github.com/neg-serg/cloudflare-speed-cli/releases/download/v${version}/cloudflare-speedtest-x86_64-unknown-linux-gnu.tar.gz";
    hash = "";
  };

  nativeBuildInputs = [ autoPatchelfHook makeWrapper ];
  sourceRoot = ".";

  installPhase = ''
    install -Dm755 cloudflare-speedtest $out/bin/cloudflare-speedtest
  '';

  meta = with lib; {
    description = "Cloudflare speed test CLI";
    homepage = "https://github.com/neg-serg/cloudflare-speed-cli";
    license = licenses.mit;
    mainProgram = "cloudflare-speedtest";
    platforms = platforms.linux;
  };
}
