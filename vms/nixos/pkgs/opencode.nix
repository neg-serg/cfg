{ lib, buildGoModule, fetchFromGitHub }:

buildGoModule rec {
  pname = "opencode";
  version = "1.24.0";

  src = fetchFromGitHub {
    owner = "sst";
    repo = "opencode";
    rev = "v${version}";
    hash = "";
  };

  vendorHash = "";

  meta = with lib; {
    description = "Open-source alternative to Cursor/Copilot CLI for AI-assisted coding";
    homepage = "https://github.com/sst/opencode";
    license = licenses.mit;
    mainProgram = "opencode";
    platforms = platforms.linux;
  };
}
