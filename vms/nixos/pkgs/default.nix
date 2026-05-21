{ callPackage }:

# Custom package derivations — equivalents of build/pkgbuilds/* PKGBUILDs
# Each .nix file below is a Nix derivation for one custom package.
# Uncomment each file as it is created (Phase 3 — US1).

{
  # Python packages
  proxypilot      = callPackage ./proxypilot.nix {};
  neg-pretty-printer = callPackage ./neg-pretty-printer.nix {};

  # Rust binaries
  ssh-to-age      = callPackage ./ssh-to-age.nix {};

  # Custom tools
  raise           = callPackage ./raise.nix {};
  richcolors      = callPackage ./richcolors.nix {};
  albumdetails    = callPackage ./albumdetails.nix {};
  taoup           = callPackage ./taoup.nix {};
  sidecar         = callPackage ./sidecar.nix {};
  tailray         = callPackage ./tailray.nix {};
  throne          = callPackage ./throne.nix {};

  # Forked packages
  duf             = callPackage ./duf.nix {};
  wl              = callPackage ./wl.nix {};

  # Fonts
  iosevka-neg-fonts = callPackage ./iosevka-neg-fonts.nix {};
}
