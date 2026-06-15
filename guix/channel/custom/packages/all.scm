(define-module (custom packages all)
  #:use-module (custom packages albumdetails)
  #:use-module (custom packages aliae)
  #:use-module (custom packages amdgpu-switcher)
  #:use-module (custom packages ananicy-cpp)
  #:use-module (custom packages bazecor)
  #:use-module (custom packages binaries)
  #:use-module (custom packages bulk-binaries)
  #:use-module (custom packages bucklespring)
  #:use-module (custom packages chawan)
  #:use-module (custom packages clipcat)
  #:use-module (custom packages choose)
  #:use-module (custom packages cosmic-icon-theme)
  #:use-module (custom packages ddccontrol)
  #:use-module (custom packages dool)
  #:use-module (custom packages droidcam)
  #:use-module (custom packages duf)
  #:use-module (custom packages dust)
  #:use-module (custom packages epr)
  #:use-module (custom packages flclashx)
  #:use-module (custom packages font-iosevkaterm-nerd-fonts)
  #:use-module (custom packages font-material-design-icons)
  #:use-module (custom packages grafana)
  #:use-module (custom packages ght)
  #:use-module (custom packages gist)
  #:use-module (custom packages go-yq)
  #:use-module (custom packages gopass)
  #:use-module (custom packages goverlay)
  #:use-module (custom packages handlr)
  #:use-module (custom packages httpie)
  #:use-module (custom packages himalaya)
  #:use-module (custom packages hishtory)
  #:use-module (custom packages instagram-cli)
  #:use-module (custom packages iperf3)
  #:use-module (custom packages iosevka-nerd-fonts)
  #:use-module (custom packages jetm-kernel-settings)
  #:use-module (custom packages judy)
  #:use-module (custom packages kanata)
  #:use-module (custom packages kmon)
  #:use-module (custom packages libjodycode)
  #:use-module (custom packages limine)
  #:use-module (custom packages massren)
  #:use-module (custom packages neg-pretty-printer)
  #:use-module (custom packages neo-matrix)
  #:use-module (custom packages newsraft)
  #:use-module (custom packages ollama)
  #:use-module (custom packages oports)
  #:use-module (custom packages optiscaler)
  #:use-module (custom packages otter-launcher)
  #:use-module (custom packages par)
  #:use-module (custom packages pop-icon-theme)
  #:use-module (custom packages powerlevel10k)
  #:use-module (custom packages proteinview)
  #:use-module (custom packages proton-cachyos)
  #:use-module (custom packages proton-ge)
  #:use-module (custom packages protontricks)
  #:use-module (custom packages proxypilot)
  #:use-module (custom packages pup)
  #:use-module (custom packages python-minidb)
  #:use-module (custom packages python-ports)
  #:use-module (custom packages python-uv-dynamic-versioning)
  #:use-module (custom packages pzip)
  #:use-module (custom packages regex-tui)
  #:use-module (custom packages rmlint)
  #:use-module (custom packages richcolors)
  #:use-module (custom packages rofi-file-browser-extended)
  #:use-module (custom packages rsmetrx)
  #:use-module (custom packages rustmission)
  #:use-module (custom packages sonic-visualiser)
  #:use-module (custom packages sbctl)
  #:use-module (custom packages sidecar)
  #:use-module (custom packages sing-box)
  #:use-module (custom packages slsa-verifier)
  #:use-module (custom packages songfetch)
  #:use-module (custom packages spdlog-1_17)
  #:use-module (custom packages source-ports)
  #:use-module (custom packages tailray)
  #:use-module (custom packages tailscale)
  #:use-module (custom packages tanin)
  #:use-module (custom packages taoup)
  #:use-module (custom packages tessen)
  #:use-module (custom packages tmmpr)
  #:use-module (custom packages unflac)
  #:use-module (custom packages v2raya)
  #:use-module (custom packages vicinae)
  #:use-module (custom packages winetricks)
  #:use-module (custom packages wlr-which-key)
  #:use-module (custom packages wl)
  #:use-module (custom packages xdg-desktop-portal-termfilechooser)
  #:use-module (custom packages xray)
  #:use-module (custom packages youtube-tui)
  #:use-module (custom packages ytsurf)
  #:use-module (custom packages zapret2)
  #:use-module (custom packages zen-browser)
  #:use-module (custom packages zmap)
  #:use-module (custom packages hermes-agent)
  #:use-module (custom packages mpdas)
  #:use-module (custom packages parity-push)  ; grex, nms, nvtop, s-tui, ssh-to-age, geoip-db
  #:use-module (custom packages ambxst)
  #:use-module (custom packages hunspell-dict-ru)
  #:use-module (custom packages iosevka-neg-fonts)
  #:use-module (custom packages quickshell)
  #:use-module (custom packages source-ioping)
  #:use-module (custom packages source-misc)
  #:use-module (custom packages themix)
  #:use-module (custom packages nicotine+)
  #:use-module (custom packages nerdctl)
  #:use-module (custom packages opencode)
  #:use-module (custom packages urlwatch)
  #:use-module (custom packages uwsm)
  #:use-module (custom packages wiremix)
  #:use-module (custom packages firewalld)
  #:use-module (custom packages gamescope)
  #:use-module (custom packages ghostty)
  #:use-module (custom packages satty)
  #:use-module (custom packages swayosd)
  #:use-module (custom packages television))

(define-public all-custom-packages
  (list
    act-bin advancecomp albumdetails aliae amdgpu-vulkan-switcher
    ananicy-cpp babashka carapace-bin clipcat cosmic-icon-theme
    dcfldd ddccontrol eilmeldung
    epr flclashx font-iosevka-nerd-fonts
    font-iosevkaterm-nerd-fonts font-material-design-icons freeze fsel
    gh-cli ghgrab ght gist     go-yq
    duf dust choose httpie
    glow-markdown gmap gopass goverlay gowall
    handlr hermes-agent himalaya hishtory hxd hyprscratch
    instagram-cli jdupes judy jetm-kernel-settings kanata kmon lazygit-bin
    iperf3
    lazytail libjodycode limine localsend lutgen massren
    mpdas neg-pretty-printer neo-matrix oh-my-posh opensoundmeter
    oports optiscaler otter-launcher overskride oyo par pop-icon-theme powerlevel10k
    proteinview protontricks protonup-rs proxypilot pup
     python-ascii-magic python-cmake-language-server python-minidb
     python-neovim-remote
    python-rapidgzip python-uv-dynamic-versioning python-vdf pzip
    reddix regex-tui repeater resterm richcolors
    rsmetrx rustmission sidecar simutil
    sing-box slsa-verifier sonic-visualiser songfetch
    sbctl
    strace-tui systemd-manager-tui tailray tailscale tanin taoup tdl
    throne tmmpr v2raya watchtower winetricks
    wlr-which-key xdg-ninja xray ytsurf zapret2
    zellij-bin zen-browser zmap
    ;; parity-push batch (27 packages)
    yazi ruff-linter gitleaks-sec ttyd-share genact-activity
    ctop-monitor onefetch-info erdtree-disk bandwhich-net
    resvg-render doggo-dns xh-client lnav-log cpufetch-tool
    viu-viewer sops-secrets taplo-fmt tabiew-tui goose-ai
    sad-editor axctl-compositor grex-tool no-more-secrets-nms
    nvtop-monitor s-tui-stress ssh-to-age-key geoip-database-maxmind
    ;; nicotine+ — removed: uses backquote macro at load time which fails
    ;; python-ports extras — python-scdl/texicode/sqlit removed: missing deps (python-curl-cffi etc.)
    ;; missing single-module entries
    ;; (roomeqwizard, xwaylandvideobridge: local-file blobs missing)
    ;; dualsensectl: hash mismatch, needs update
    ambxst chawan droidcam hunspell-dict-ru
    bucklespring
    font-iosevka-neg
    firewalld gamescope ghostty satty swayosd television
    ghostty-bin gitlogue htmlq matugen rmpc wsdd
    ioping newsraft ollama proton-cachyos proton-ge-custom
    grafana
    quickshell rmlint rofi-file-browser-extended
    themix-theme-oomox tessen unflac vicinae wl
    xdg-desktop-portal-termfilechooser youtube-tui
    ;; new packages
    nerdctl opencode urlwatch uwsm wiremix
    ;; source-misc
    fortune-mod
    ))

all-custom-packages
