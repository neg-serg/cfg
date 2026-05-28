{ lib, stdenv, fetchFromGitHub }:

stdenv.mkDerivation rec {
  pname = "hxd";
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "kiedtl";
    repo = "huxdemp";
    rev = "1.0.0";
    hash = "sha256-PIbnSTp1Lxa1cVfLJrJh4e+JPzPsfy2VpdJuy5X5tyQ=";
  };

  installPhase = ''
    mkdir -p $out/bin
    cp hxd $out/bin/ 2>/dev/null || cp target/release/hxd $out/bin/
  '';

  meta = with lib; {
    description = "Hex dump tool (huxdemp)";
    homepage = "https://github.com/kiedtl/huxdemp";
    license = licenses.mit;
    mainProgram = "hxd";
    platforms = platforms.linux;
  };
}
