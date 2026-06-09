{
  lib,
  stdenvNoCC,
  fetchurl,
  ...
}:

stdenvNoCC.mkDerivation rec {
  pname = "borgbackup";
  version = "1.4.0";

  src = fetchurl {
    url = "https://github.com/borgbackup/borg/releases/download/${version}/borg-linux-glibc2";
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };

  dontUnpack = true;

  installPhase = ''
    install -Dm755 $src $out/bin/borg
  '';

  meta = with lib; {
    description = "Deduplicating backup tool (static binary)";
    homepage = "https://www.borgbackup.org";
    license = licenses.bsd3;
    maintainers = [];
    platforms = platforms.linux;
  };
}
