{ lib, stdenv, fetchurl, makeWrapper, jre }:

stdenv.mkDerivation rec {
  pname = "roomeqwizard";
  version = "5.40.1";

  src = fetchurl {
    url = "https://www.roomeqwizard.com/REW_linux_${version}.zip";
    hash = lib.fakeSha256;  # FIXME: build once to get real hash
  };

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    mkdir -p $out/bin $out/lib/rew
    cp -r * $out/lib/rew/
    makeWrapper ${jre}/bin/java $out/bin/rew \
      --add-flags "-jar $out/lib/rew/REW.jar"
  '';

  meta = with lib; {
    description = "Room EQ Wizard — room acoustics measurement and analysis software";
    homepage = "https://www.roomeqwizard.com/";
    license = licenses.unfree;
    maintainers = [ ];
    platforms = platforms.linux;
    mainProgram = "rew";
  };
}