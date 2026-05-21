{ lib, rustPlatform, fetchFromGitHub, dbus, pkg-config }:

rustPlatform.buildRustPackage rec {
  pname = "tailray";
  version = "0.3.0";

  src = fetchFromGitHub {
    owner = "NotAShelf";
    repo = "tailray";
    rev = "v${version}";
    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };

  cargoHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ dbus ];

  meta = with lib; {
    description = "Tailscale tray icon for Wayland";
    homepage = "https://github.com/NotAShelf/tailray";
    license = licenses.mit;
    mainProgram = "tailray";
  };
}
