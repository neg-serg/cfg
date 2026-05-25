{ lib, stdenvNoCC, fetchurl, autoPatchelfHook, }:

stdenvNoCC.mkDerivation rec {
  pname = "reddix";  version = "0.2.9";
  src = fetchurl {
    url = "https://github.com/ck-zhang/reddix/releases/download/v${version}/reddix-x86_64-unknown-linux-gnu.tar.xz";
    sha256 = "sha256-XRGV/mcpv+fUGwx8mq0S4eEcHrlTLWjZcEhh1BMXkgE=";
  };
  sourceRoot = ".";
  nativeBuildInputs = [ autoPatchelfHook ];
  installPhase = ''
    mkdir -p $out/bin
    [ -f reddix ] && cp reddix $out/bin/ || cp reddix-x86_64-unknown-linux-gnu/reddix $out/bin/
    chmod +x $out/bin/reddix
  '';
  meta = with lib; {
    description = "Reddix — Reddit client (Rust)";
    homepage = "https://github.com/ck-zhang/reddix";
    license = licenses.mit;  platforms = [ "x86_64-linux" ];
  };
}
