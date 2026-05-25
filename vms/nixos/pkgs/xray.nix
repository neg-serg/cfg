{
  lib, stdenvNoCC, fetchurl, autoPatchelfHook, unzip,
}:

stdenvNoCC.mkDerivation rec {
  pname = "xray";  version = "26.5.9";
  src = fetchurl {
    url = "https://github.com/XTLS/Xray-core/releases/download/v${version}/Xray-linux-64.zip";
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };
  sourceRoot = ".";  nativeBuildInputs = [ unzip autoPatchelfHook ];
  installPhase = '' mkdir -p $out/bin; cp xray $out/bin/ '';
  meta = with lib; {
    description = "Xray proxy core (pre-built)"; homepage = "https://github.com/XTLS/Xray-core";
    license = licenses.mpl20;  platforms = [ "x86_64-linux" ];
  };
}
