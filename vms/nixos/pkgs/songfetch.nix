{
  lib,
  stdenvNoCC,
  fetchFromGitLab,
  meson,
  ninja,
  pkg-config,
  ...
}:

stdenvNoCC.mkDerivation rec {
  pname = "songfetch";
  version = "2.1.2";

  src = fetchFromGitLab {
    owner = "kurtz";
    repo = "songfetch";
    rev = "v${version}";
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };

  meta = with lib; {
    description = "Song info fetcher (MPD/Last.fm, Rust)";
    homepage = "https://gitlab.com/kurtz/songfetch";
    license = licenses.mit;
    maintainers = [];
    platforms = platforms.linux;
  };
}
