{
  lib,
  stdenvNoCC,
  fetchurl,
  unzip,
  ...
}:

stdenvNoCC.mkDerivation rec {
  pname = "turbostat";
  version = "6.18";

  src = fetchurl {
    url = "https://kernel.org/pub/linux/kernel/v6.x/linux-${version}.tar.xz";
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };

  sourceRoot = "linux-${version}/tools/power/x86/turbostat";

  installPhase = ''
    make turbostat
    install -Dm755 turbostat $out/bin/turbostat
  '';

  meta = with lib; {
    description = "Intel CPU turbo/energy status monitor (from linux kernel tools)";
    homepage = "https://www.kernel.org";
    license = licenses.gpl2Only;
    maintainers = [];
    platforms = platforms.linux;
  };
}
