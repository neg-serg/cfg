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

    # ── Parity push: new overlays ──
    aliae-bin            = final.callPackage ./aliae-bin.nix {};
    antigravity-tools-bin = final.callPackage ./antigravity-tools-bin.nix {};
    eilmeldung-bin       = final.callPackage ./eilmeldung-bin.nix {};
    #flclashx-bin         = final.callPackage ./flclashx-bin.nix {};
    gitlogue             = final.callPackage ./gitlogue.nix {};
    grex                 = final.callPackage ./grex.nix {};
    #hxd                  = final.callPackage ./hxd-bin.nix {};
    #hyprscratch          = final.callPackage ./hyprscratch.nix {};
    instagram-cli         = final.callPackage ./instagram-cli.nix {};
    #kanata               = final.callPackage ./kanata-bin.nix {};
    lazytail             = final.callPackage ./lazytail-bin.nix {};
    neo-matrix           = final.callPackage ./neo-matrix-bin.nix {};
    no-more-secrets       = final.callPackage ./no-more-secrets.nix {};
    opencode             = final.callPackage ./opencode.nix {};
    oports-git           = final.callPackage ./oports-git.nix {};
    otter-launcher       = final.callPackage ./otter-launcher.nix {};
    oyo                  = final.callPackage ./oyo.nix {};
    pipemixer            = final.callPackage ./pipemixer.nix {};
    qman                 = final.callPackage ./qman.nix {};
    rofi-file-browser-extended = final.callPackage ./rofi-file-browser-extended.nix {};
    #s-tui                = final.callPackage ./s-tui.nix {};
    strace-tui           = final.callPackage ./strace-tui.nix {};
    tdl                  = final.callPackage ./tdl-bin.nix {};
    yandex-browser       = final.callPackage ./yandex-browser-bin.nix {};

    # ── Parity push: final batch ──
    bottles              = prev.bottles;  # from nixpkgs (AppImage no longer published)
    cloudflare-speedtest = final.callPackage ./cloudflare-speed-cli.nix {};
    droidcam             = final.callPackage ./droidcam.nix {};
    goverlay             = final.callPackage ./goverlay.nix {};
    hyprquickframe       = final.callPackage ./hyprquickframe.nix {};
    #opensoundmeter        = final.callPackage ./opensoundmeter.nix {};
    #proton-ge-custom     = final.callPackage ./proton-ge-custom.nix {};
    protonup-rs          = final.callPackage ./protonup-rs.nix {};
  };
in
{
  nixpkgs.overlays = [ customOverlay ];
}
