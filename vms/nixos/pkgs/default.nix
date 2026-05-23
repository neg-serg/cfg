{ config, pkgs, lib, ... }:

let
  customOverlay = final: prev: {
    proxypilot      = final.callPackage ./proxypilot.nix {};
    neg-pretty-printer = final.callPackage ./neg-pretty-printer.nix {};
    ssh-to-age      = final.callPackage ./ssh-to-age.nix {};
    raise           = final.callPackage ./raise.nix {};
    richcolors      = final.callPackage ./richcolors.nix {};
    albumdetails    = final.callPackage ./albumdetails.nix {};
    taoup           = final.callPackage ./taoup.nix {};
    sidecar         = final.callPackage ./sidecar.nix {};
    tailray         = final.callPackage ./tailray.nix {};
    throne          = final.callPackage ./throne.nix {};
    duf             = final.callPackage ./duf.nix {};
    wl              = final.callPackage ./wl.nix {};
    iosevka-neg-fonts = final.callPackage ./iosevka-neg-fonts.nix {};
    vicinae-bin     = final.callPackage ./vicinae-bin.nix {};
    zen-browser     = final.callPackage ./zen-browser.nix {};
  };
in
{
  nixpkgs.overlays = [ customOverlay ];
}
