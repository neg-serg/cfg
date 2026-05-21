{ lib, stdenvNoCC, buildNpmPackage, fetchFromGitHub, nerd-font-patcher, fontforge, python3, ttfautohint-nox }:

let
  version = "34.1.0";
  pname = "iosevka-neg";
  tomlFile = ./iosevka-neg.toml;

  iosevkaRaw = buildNpmPackage {
    pname = "${pname}-raw";
    inherit version;

    src = fetchFromGitHub {
      owner = "be5invis";
      repo = "Iosevka";
      tag = "v${version}";
      hash = "sha256-vdjf2MkKP9DHl/hrz9xJMWMuT2AsonRdt14xQTSsVmU=";
    };

    npmDepsHash = "sha256-YMfePtKg4kpZ4iCpkq7PxfyDB4MIRg/tgCNmLD31zKo=";

    nativeBuildInputs = [ ttfautohint-nox ];

    strictDeps = true;

    configurePhase = ''
      runHook preConfigure
      cp ${tomlFile} private-build-plans.toml
      runHook postConfigure
    '';

    buildPhase = ''
      export HOME=$TMPDIR
      runHook preBuild
      npm run build --no-update-notifier --targets ttf::Iosevkaneg -- --jCmd=$NIX_BUILD_CORES --verbosity=9 | cat
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out/share/fonts
      cp dist/IosevkaNeg/TTF/*.ttf $out/share/fonts/
      runHook postInstall
    '';

    enableParallelBuilding = true;
    requiredSystemFeatures = [ "big-parallel" ];

    meta = with lib; {
      homepage = "https://typeof.net/Iosevka/";
      license = licenses.ofl;
      platforms = platforms.all;
    };
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
