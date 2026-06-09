{ lib, stdenv, fetchFromGitHub, cmake, pkg-config, hyprland }:

stdenv.mkDerivation rec {
  pname = "hyprscratch";
  version = "0.6.4";

  src = fetchFromGitHub {
    owner = "sashetophizika";
    repo = "hyprscratch";
    rev = "v${version}";
    hash = "";
  };

  nativeBuildInputs = [ cmake pkg-config ];
  buildInputs = [ hyprland ];

  meta = with lib; {
    description = "Hyprland scratchpad utility";
    homepage = "https://github.com/sashetophizika/hyprscratch";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
