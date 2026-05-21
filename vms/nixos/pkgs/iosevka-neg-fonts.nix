{ lib, stdenvNoCC, fetchFromGitHub, nodejs, fontforge, python3, ttfautohint }:

let
  version = "34.1.0";
  tomlFile = ./iosevka-neg.toml;

  # Build Iosevka fonts from the custom build plan
  iosevkaFonts = stdenvNoCC.mkDerivation {
    pname = "iosevka-neg-fonts-raw";
    inherit version;

    src = fetchFromGitHub {
      owner = "be5invis";
      repo = "Iosevka";
      rev = "v${version}";
      hash = "sha256-NOJn4890xP63YiMhuNEesyMQ+fBbi6gDp+RsbMcYh3M=";
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

  # Patch with Nerd Font glyphs
  nerdFontPatcher = fetchFromGitHub {
    owner = "ryanoasis";
    repo = "nerd-fonts";
    rev = "v3.4.0";
    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };
in
stdenvNoCC.mkDerivation {
  pname = "iosevka-neg-fonts";
  inherit version;

  src = iosevkaFonts;

  nativeBuildInputs = [ fontforge python3 ttfautohint ];

  buildPhase = ''
    mkdir -p patched
    for ttf in $src/share/fonts/*.ttf; do
      fontforge -script ${nerdFontPatcher}/font-patcher \
        --complete --outputdir patched "$ttf"
    done

  '';
  # Strip "Nerd Font" from family names
  # (Python fontTools script from the PKGBUILD)
  fixupPhase = ''
    python3 -c "
from fontTools.ttLib import TTFont
import glob, os
for f in glob.glob('patched/*.ttf'):
    tt = TTFont(f)
    name = tt['name']
    for record in name.names:
        if record.nameID in (1, 3, 4, 6, 16, 21):
            s = record.toUnicode()
            if 'Nerd Font' in s:
                s = s.replace(' Nerd Font', "")
                record.string = s
    tt.save(f + '.tmp')
    os.rename(f + '.tmp', f)
"
    '';

  installPhase = ''
    mkdir -p $out/share/fonts/TTF
    cp patched/*.ttf $out/share/fonts/TTF/
  '';

  meta = with lib; {
    description = "Iosevka Neg custom font with Nerd Font patching";
    homepage = "https://github.com/be5invis/Iosevka";
    license = licenses.ofl;
    platforms = platforms.all;
  };
}
