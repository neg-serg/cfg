{ lib, buildGoModule, fetchFromGitHub }:

buildGoModule rec {
  pname = "no-more-secrets";
  version = "1.0.1";

  src = fetchFromGitHub {
    owner = "bartobri";
    repo = "no-more-secrets";
    rev = "v${version}";
    hash = "";
  };

  vendorHash = "";

  meta = with lib; {
    description = "Recreation of the 'decrypting text' effect from the 1992 movie Sneakers";
    homepage = "https://github.com/bartobri/no-more-secrets";
    license = licenses.gpl3;
    mainProgram = "nms";
    platforms = platforms.linux;
  };
}
