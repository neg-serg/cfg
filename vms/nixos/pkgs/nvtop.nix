{
  lib,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  ...
}:

stdenvNoCC.mkDerivation rec {
  pname = "nvtop";
  version = "3.2.0";

  src = fetchurl {
    url = "https://github.com/Syllo/nvtop/releases/download/${version}/nvtop-${version}-x86_64.AppImage";
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };

  dontUnpack = true;

  nativeBuildInputs = [ autoPatchelfHook ];

  installPhase = ''
    install -Dm755 $src $out/bin/nvtop
  '';

  meta = with lib; {
    description = "GPU process monitor (like htop for GPUs)";
    homepage = "https://github.com/Syllo/nvtop";
    license = licenses.gpl3Plus;
    maintainers = [];
    platforms = platforms.linux;
  };
}
