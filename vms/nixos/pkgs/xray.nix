{ lib, stdenvNoCC, fetchurl, unzip, autoPatchelfHook, }:

stdenvNoCC.mkDerivation rec {
  pname = "xray";  version = "26.5.9";
  src = fetchurl {
    url = "https://github.com/XTLS/Xray-core/releases/download/v${version}/Xray-linux-64.zip";
    sha256 = "sha256-9WwQa3wBWa04a8zTQPqlu/Vf1cFYIeyeY+amuhHT0cc=";
  };
  nativeBuildInputs = [ unzip ];
  installPhase = ''
    set -euo pipefail
    mkdir -p $out/bin
    ls -la  # debug: show contents
    [ -f xray ] && cp xray $out/bin/xray || [ -f xray.exe ] && cp xray.exe $out/bin/xray || echo "xray binary not found"
    chmod +x $out/bin/xray 2>/dev/null || true
  '';
  meta = with lib; { description = "Xray proxy core (pre-built)"; homepage = "https://github.com/XTLS/Xray-core"; license = licenses.mpl20; platforms = [ "x86_64-linux" ]; };
}
