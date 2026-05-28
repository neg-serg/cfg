{ lib, stdenv, fetchFromGitHub, cmake, pkg-config, hyprland, pango, cairo, libdrm }:

stdenv.mkDerivation rec {
  pname = "rofi-file-browser-extended";
  version = "1.3.0";

  src = fetchFromGitHub {
    owner = "marvinkreis";
    repo = "rofi-file-browser-extended";
    rev = "v${version}";
    hash = "";
  };

  nativeBuildInputs = [ cmake pkg-config ];
  buildInputs = [ hyprland pango cairo libdrm ];

  meta = with lib; {
    description = "Extended file browser for rofi";
    homepage = "https://github.com/marvinkreis/rofi-file-browser-extended";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
