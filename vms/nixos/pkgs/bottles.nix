{ lib, stdenv, fetchurl, autoPatchelfHook, makeWrapper, xorg, vulkan-loader }:

stdenv.mkDerivation rec {
  pname = "bottles";
  version = "51.17";

  src = fetchurl {
    url = "https://github.com/bottlesdevs/Bottles/releases/download/${version}/bottles-${version}-x86_64.AppImage";
    hash = "";  # FIXME: latest tag is 63.2, update version above
  };

  nativeBuildInputs = [ autoPatchelfHook makeWrapper ];
  buildInputs = [ xorg.libX11 vulkan-loader ];

  dontUnpack = true;

  installPhase = ''
    install -Dm755 $src $out/bin/bottles
  '';

  meta = with lib; {
    description = "Easily manage wine prefixes in a new way";
    homepage = "https://usebottles.com";
    license = licenses.gpl3Only;
    mainProgram = "bottles";
    platforms = platforms.linux;
  };
}
