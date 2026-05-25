{ lib, stdenvNoCC, fetchurl, autoPatchelfHook, }:

stdenvNoCC.mkDerivation rec {
  pname = "v2raya";  version = "2.2.7.5";
  src = fetchurl {
    url = "https://github.com/v2rayA/v2rayA/releases/download/v${version}/v2raya_linux_x64_${version}";
    sha256 = "sha256-M7wfTu4PIbBqjhOTswZoO2ISM8MSPyup1/QFDOfVXTM=";
  };
  dontUnpack = true;
  nativeBuildInputs = [ autoPatchelfHook ];
  installPhase = ''
    mkdir -p $out/bin
    cp $src $out/bin/v2raya
    chmod +x $out/bin/v2raya
  '';
  meta = with lib; { description = "V2Ray web frontend"; homepage = "https://github.com/v2rayA/v2rayA"; license = licenses.agpl3Plus; platforms = [ "x86_64-linux" ]; };
}
