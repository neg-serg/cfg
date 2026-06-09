{ lib, stdenv, fetchFromGitHub, meson, ninja, pkg-config, glib, gtk3, wrapGAppsHook3 }:

stdenv.mkDerivation rec {
  pname = "goverlay";
  version = "1.3";

  src = fetchFromGitHub {
    owner = "benjamimgois";
    repo = "goverlay";
    rev = version;
    hash = "sha256-xqA6FfPfQPZ+aDASjAKMBI1T8Ez0sH8qJ9+Ve0PyUZY=";
  };

  nativeBuildInputs = [ meson ninja pkg-config wrapGAppsHook3 ];
  buildInputs = [ glib gtk3 ];

  meta = with lib; {
    description = "GUI for configuring MangoHud and vkBasalt";
    homepage = "https://github.com/benjamimgois/goverlay";
    license = licenses.gpl3Only;
    mainProgram = "goverlay";
    platforms = platforms.linux;
  };
}
