{ lib, stdenv, fetchFromGitHub, cmake, pkg-config, rofi, pango, cairo, libdrm }:

stdenv.mkDerivation rec {
  pname = "rofi-file-browser-extended";
  version = "1.3.1";

  src = fetchFromGitHub {
    owner = "marvinkreis";
    repo = "rofi-file-browser-extended";
    rev = "${version}";
    hash = "sha256-UEFv0skFzWhgFkmz1h8uV1ygW977zNq1Dw8VAawqUgw=";
  };

  nativeBuildInputs = [ cmake pkg-config ];
  buildInputs = [ rofi pango cairo libdrm ];

  meta = with lib; {
    description = "Extended file browser for rofi";
    homepage = "https://github.com/marvinkreis/rofi-file-browser-extended";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
