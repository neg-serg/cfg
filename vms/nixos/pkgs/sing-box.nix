{ lib, stdenvNoCC, fetchurl, autoPatchelfHook, }:

stdenvNoCC.mkDerivation rec {
  pname = "sing-box";
  version = "1.13.12";

  src = fetchurl {
    url = "https://github.com/SagerNet/sing-box/releases/download/v${version}/sing-box-${version}-linux-amd64.tar.gz";
    sha256 = "sha256-FUBTOts98k9a1fFLXHyj28JAGxChwesnj8rcraR+xsQ=";
  };

  sourceRoot = "sing-box-${version}-linux-amd64";
  nativeBuildInputs = [ autoPatchelfHook ];

  installPhase = ''
    mkdir -p $out/bin
    cp sing-box $out/bin/sing-box
    chmod +x $out/bin/sing-box
  '';

  meta = with lib; {
    description = "Universal proxy platform (SagerNet)";
    homepage = "https://github.com/SagerNet/sing-box";
    license = licenses.gpl3Plus;
    maintainers = [];
    platforms = [ "x86_64-linux" ];
  };
}
