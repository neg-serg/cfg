{ lib, stdenvNoCC, fetchurl, }:

stdenvNoCC.mkDerivation rec {
  pname = "zapret2";  version = "0.9.5.2";
  src = fetchurl {
    url = "https://github.com/bol-van/zapret2/releases/download/v${version}/zapret2-v${version}.tar.gz";
    sha256 = "sha256-T4YS/GF8mhk3yiFfhbttcAX1RV4VKo9/HdZmw4oIDcg=";
  };
  sourceRoot = ".";   # auto-stripped by unpackPhase
  installPhase = ''
    mkdir -p $out/bin $out/opt/zapret2
    find . -maxdepth 1 -not -name '.' -not -name '..' | while read -r f; do
      cp -r "$f" $out/opt/zapret2/ 2>/dev/null || true
    done
    cat > $out/bin/zapret2 <<'SCRIPT'
#!/bin/sh
echo "Zapret2 DPI bypass v${version}"
echo "Run: /opt/zapret2/install_easy.sh"
SCRIPT
    chmod +x $out/bin/zapret2
  '';
  meta = with lib; { description = "DPI bypass"; homepage = "https://github.com/bol-van/zapret2"; license = licenses.gpl3Plus; platforms = platforms.linux; };
}
