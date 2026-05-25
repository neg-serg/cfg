{ lib, stdenvNoCC, fetchurl, }:
stdenvNoCC.mkDerivation rec {
  pname = "zapret2";  version = "0.9.5.2";
  src = fetchurl {
    url = "https://github.com/bol-van/zapret2/releases/download/v${version}/zapret2-v${version}.tar.gz";
    sha256 = "sha256-T4YS/GF8mhk3yiFfhbttcAX1RV4VKo9/HdZmw4oIDcg=";
  };
  sourceRoot = ".";
  installPhase = ''
    mkdir -p $out/bin $out/opt/zapret2
    cp -r * $out/opt/zapret2/ 2>/dev/null || true
    cat > $out/bin/zapret2 <<'EOF'
#!/bin/sh
echo "Zapret2 DPI bypass. Run: /opt/zapret2/install_easy.sh"
EOF
    chmod +x $out/bin/zapret2
  '';
  meta = with lib; { description = "DPI bypass (discord,youtube)"; homepage = "https://github.com/bol-van/zapret2"; license = licenses.gpl3Plus; platforms = platforms.linux; };
}
