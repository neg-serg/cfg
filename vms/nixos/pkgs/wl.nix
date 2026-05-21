{ lib, rustPlatform, fetchFromGitHub, pkg-config, wayland, libffi, wayland-protocols }:

rustPlatform.buildRustPackage rec {
  pname = "wl";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "neg-serg";
    repo = "wl";
    rev = "main";
    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };

  cargoHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";

  nativeBuildInputs = [ pkg-config wayland-protocols ];
  buildInputs = [ wayland libffi ];

  meta = with lib; {
    description = "Wayland wallpaper daemon — fork of swww with Vulkan backend";
    homepage = "https://github.com/neg-serg/wl";
    license = licenses.gpl3;
    mainProgram = "wl";
  };
}
