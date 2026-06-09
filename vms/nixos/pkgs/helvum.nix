{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  installShellFiles,
  ...
}:

stdenvNoCC.mkDerivation rec {
  pname = "helvum";
  version = "0.6.0";

  src = fetchFromGitHub {
    owner = "mxsash";
    repo = "helvum";
    rev = "v${version}";
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };

  nativeBuildInputs = [ installShellFiles ];
  dontBuild = true;

  installPhase = ''
    install -Dm755 helvum $out/bin/helvum
  '';

  meta = with lib; {
    description = "PipeWire graph editor (GTK)";
    homepage = "https://gitlab.freedesktop.org/pipewire/helvum";
    license = licenses.gpl3Plus;
    maintainers = [];
    platforms = platforms.linux;
  };
}
