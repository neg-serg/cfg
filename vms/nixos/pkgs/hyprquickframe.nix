{ lib, stdenv, fetchFromGitHub, autoPatchelfHook, makeWrapper }:

stdenv.mkDerivation rec {
  pname = "hyprquickframe";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "Ronin-CK";
    repo = "HyprQuickFrame";
    rev = "61fe0ef";  # r92.g61fe0ef
    hash = "sha256-JwqbPTtyvH+7zCmh9VUX/sSbxuYuo1QftXB0pwcSIac=";
  };

  nativeBuildInputs = [ autoPatchelfHook makeWrapper ];

  installPhase = ''
    mkdir -p $out/bin
    cp hyprquickframe $out/bin/ 2>/dev/null || true
  '';

  meta = with lib; {
    description = "Quick frame capture for Hyprland";
    homepage = "https://github.com/Ronin-CK/HyprQuickFrame";
    license = licenses.mit;
    mainProgram = "hyprquickframe";
    platforms = platforms.linux;
  };
}
