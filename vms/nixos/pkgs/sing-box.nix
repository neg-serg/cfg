{
  lib,
  stdenvNoCC,
  fetchurl,
  unzip,
  autoPatchelfHook,
}:

stdenvNoCC.mkDerivation rec {
  pname = "sing-box";
  version = "1.13.12";

  src = fetchurl {
    url = "https://github.com/SagerNet/sing-box/releases/download/v${version}/sing-box-${version}-linux-amd64.tar.gz";
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };

  sourceRoot = ".";
  nativeBuildInputs = [ autoPatchelfHook ];

  buildInputs = [ unzip ];

  installPhase = ''
    mkdir -p $out/bin
    mv sing-box $out/bin/
  '';

  meta = with lib; {
    description = "Universal proxy platform (SagerNet)";
    homepage = "https://github.com/SagerNet/sing-box";
    license = licenses.gpl3Plus;
    maintainers = [];
    platforms = [ "x86_64-linux" ];
  };
}
