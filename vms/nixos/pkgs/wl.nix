{ lib, rustPlatform, fetchFromGitHub, pkg-config, wayland, libffi, wayland-protocols, shaderc }:

rustPlatform.buildRustPackage rec {
  pname = "wl";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "neg-serg";
    repo = "wl";
    rev = "main";
    hash = "sha256-mBDzV8110wdBDV/f+2FOKMZjGOkGwC0cKBudvuk/e/4=";
  };

  cargoHash = "sha256-6v7x7kMUxtwgU/j1qpKocgcIKH4rMjgG+9xLsFovhWY=";

  nativeBuildInputs = [ pkg-config wayland-protocols shaderc ];
  buildInputs = [ wayland libffi ];

  meta = with lib; {
    description = "Wayland wallpaper daemon — fork of swww with Vulkan backend";
    homepage = "https://github.com/neg-serg/wl";
    license = licenses.gpl3;
    mainProgram = "wl";
  };
}
