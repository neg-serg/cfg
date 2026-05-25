{
  lib, stdenvNoCC, fetchurl, autoPatchelfHook,
}:

stdenvNoCC.mkDerivation rec {
  pname = "zapret2";  version = "0.9.5.2";
  src = fetchurl {
    url = "https://github.com/bol-van/zapret2/releases/download/v${version}/zapret2-v${version}.tar.gz";
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };
  installPhase = ''
    mkdir -p $out/opt/zapret2
    cp -r * $out/opt/zapret2/
    mkdir -p $out/bin
    cat > $out/bin/zapret2 <<EOF
#!/bin/sh
echo "Run: /opt/zapret2/install_easy.sh"
EOF
    chmod +x $out/bin/zapret2
  '';
  meta = with lib; {
    description = "DPI bypass tool (discord, youtube, tiktok)";
    homepage = "https://github.com/bol-van/zapret2";
    license = licenses.gpl3Plus;  platforms = platforms.linux;
  };
}
