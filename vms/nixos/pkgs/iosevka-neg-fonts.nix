{ lib, stdenvNoCC, fetchFromGitHub, nodejs, fontforge, python3, nerd-font-patcher }:

let
  version = "34.1.0";
  tomlFile = ./iosevka-neg.toml;

  iosevkaRaw = stdenvNoCC.mkDerivation {
    pname = "iosevka-neg-raw";
    inherit version;

    src = fetchFromGitHub {
      owner = "be5invis";
      repo = "Iosevka";
      rev = "v${version}";
      hash = "sha256-vdjf2MkKP9DHl/hrz9xJMWMuT2AsonRdt14xQTSsVmU=";
    };

    nativeBuildInputs = [ nodejs ];

    buildPhase = ''
      cp ${tomlFile} private-build-plans.toml
      npm install
      npm run build -- contents::Iosevkaneg
    '';

    installPhase = ''
      mkdir -p $out/share/fonts
      cp dist/IosevkaNeg/TTF/*.ttf $out/share/fonts/
    '';
  };
in
stdenvNoCC.mkDerivation {
  pname = "iosevka-neg-fonts";
  inherit version;

  dontUnpack = true;

  nativeBuildInputs = [ fontforge python3 nerd-font-patcher ];

  buildPhase = ''
    mkdir -p patched
    for ttf in ${iosevkaRaw}/share/fonts/*.ttf; do
      fontforge -script ${nerd-font-patcher}/bin/font-patcher \
        --complete --outputdir patched "$ttf"
    done
  '';

  installPhase = ''
    mkdir -p $out/share/fonts/TTF
    cp patched/*.ttf $out/share/fonts/TTF/
  '';

  meta = with lib; {
    description = "Iosevka Neg custom font with Nerd Font glyphs";
    homepage = "https://github.com/be5invis/Iosevka";
    license = licenses.ofl;
    platforms = platforms.all;
  };
}
