{ config, pkgs, lib, ... }:

let
  customOverlay = final: prev: {
    albumdetails    = final.callPackage ./albumdetails.nix {};
    borgbackup      = final.callPackage ./borgbackup.nix {};
    duf             = final.callPackage ./duf.nix {};
    fortune-mod     = final.callPackage ./fortune-mod.nix {};
    geoip-database  = final.callPackage ./geoip-database.nix {};
    iosevka-neg-fonts = final.callPackage ./iosevka-neg-fonts.nix {};
    neg-pretty-printer = final.callPackage ./neg-pretty-printer.nix {};
    nvtop           = final.callPackage ./nvtop.nix {};
    proxypilot      = final.callPackage ./proxypilot.nix {};
    reddix           = final.callPackage ./reddix.nix {};
    raise           = final.callPackage ./raise.nix {};
    richcolors      = final.callPackage ./richcolors.nix {};
    rofi-calc       = final.callPackage ./rofi-calc.nix {};
    sidecar         = final.callPackage ./sidecar.nix {};
    songfetch       = final.callPackage ./songfetch.nix {};
    ssh-to-age      = final.callPackage ./ssh-to-age.nix {};
    tailray         = final.callPackage ./tailray.nix {};
    taoup           = final.callPackage ./taoup.nix {};
    throne          = final.callPackage ./throne.nix {};
    themix-theme-oomox = final.callPackage ./themix-theme-oomox.nix {};
    vicinae-bin     = final.callPackage ./vicinae-bin.nix {};
    wl              = final.callPackage ./wl.nix {};
    zen-browser     = final.callPackage ./zen-browser.nix {};
    goose             = final.callPackage ./goose.nix {};
    helvum               = final.callPackage ./helvum.nix {};
    sing-box             = final.callPackage ./sing-box.nix {};
    turbostat            = final.callPackage ./turbostat.nix {};
    xray                 = final.callPackage ./xray.nix {};
    v2raya               = final.callPackage ./v2raya.nix {};
    ytsurf               = final.callPackage ./ytsurf.nix {};
    zapret2              = final.callPackage ./zapret2.nix {};
  };
in
{
  nixpkgs.overlays = [ customOverlay ];
}
