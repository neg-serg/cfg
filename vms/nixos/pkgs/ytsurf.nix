{
  lib, stdenvNoCC, fetchurl,
}:

stdenvNoCC.mkDerivation rec {
  pname = "ytsurf";  version = "3.1.7";
  src = fetchurl {
    url = "https://github.com/Stan-breaks/ytsurf/archive/refs/tags/v${version}.tar.gz";
    sha256 = "sha256-umHon8Z0jIIwMN7IQG5MJSKqK7KU22ChQeU7lea7DiI=";
  };
  installPhase = ''
    mkdir -p $out/bin
    cp ytsurf.sh $out/bin/ytsurf 2>/dev/null || cp ytsurf $out/bin/ 2>/dev/null || true
    chmod +x $out/bin/ytsurf
  '';
  meta = with lib; {
    description = "YouTube TUI (terminal client)"; homepage = "https://github.com/Stan-breaks/ytsurf";
    license = licenses.gpl3Plus;  platforms = platforms.linux;
  };
}
