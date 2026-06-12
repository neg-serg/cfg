(define-module (custom packages all)
  #:use-module (custom packages albumdetails)
  #:use-module (custom packages aliae)
  #:use-module (custom packages amdgpu-switcher)
  #:use-module (custom packages ananicy-cpp)
  #:use-module (custom packages bazecor)
  #:use-module (custom packages binaries)
  #:use-module (custom packages bulk-binaries)
  #:use-module (custom packages chawan)
  #:use-module (custom packages clipcat)
  #:use-module (custom packages ddccontrol)
  #:use-module (custom packages dool)
  #:use-module (custom packages droidcam)
  #:use-module (custom packages dualsensectl)
  #:use-module (custom packages epr)
  #:use-module (custom packages flclashx)
  #:use-module (custom packages font-iosevkaterm-nerd-fonts)
  #:use-module (custom packages font-material-design-icons)
  #:use-module (custom packages ght)
  #:use-module (custom packages gopass)
  #:use-module (custom packages goverlay)
  #:use-module (custom packages handlr)
  #:use-module (custom packages hishtory)
  #:use-module (custom packages instagram-cli)
  #:use-module (custom packages iosevka-nerd-fonts)
  #:use-module (custom packages jetm-kernel-settings)
  #:use-module (custom packages kanata)
  #:use-module (custom packages libjodycode)
  #:use-module (custom packages limine)
  #:use-module (custom packages massren)
  #:use-module (custom packages neo-matrix)
  #:use-module (custom packages newsraft)
  #:use-module (custom packages ollama)
  #:use-module (custom packages oports)
  #:use-module (custom packages optiscaler)
  #:use-module (custom packages otter-launcher)
  #:use-module (custom packages par)
  #:use-module (custom packages powerlevel10k)
  #:use-module (custom packages proteinview)
  #:use-module (custom packages proton-cachyos)
  #:use-module (custom packages proton-ge)
  #:use-module (custom packages protontricks)
  #:use-module (custom packages proxypilot)
  #:use-module (custom packages python-ports)
  #:use-module (custom packages python-uv-dynamic-versioning)
  #:use-module (custom packages pzip)
  #:use-module (custom packages regex-tui)
  #:use-module (custom packages rmlint)
  #:use-module (custom packages richcolors)
  #:use-module (custom packages rofi-file-browser-extended)
  #:use-module (custom packages roomeqwizard)
  #:use-module (custom packages rsmetrx)
  #:use-module (custom packages rustmission)
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
  #:use-module (custom packages xwaylandvideobridge)
  #:use-module (custom packages youtube-tui)
  #:use-module (custom packages ytsurf)
  #:use-module (custom packages zapret2)
  #:use-module (custom packages zen-browser)
  #:use-module (custom packages hermes-agent)
  #:use-module (custom packages mpdas)
  #:use-module (custom packages parity-push))  ; grex, nms, nvtop, s-tui, ssh-to-age, geoip-db

(define-public all-custom-packages
  (list
    act-bin
    advancecomp
    albumdetails
    aliae
    amdgpu-vulkan-switcher
    ananicy-cpp
    babashka
    ;; FIXME: bazecor — build failure, removed
    carapace-bin
    ;; FIXME: chawan — build failure, removed
    clipcat
    dcfldd
    ddccontrol
    ;; FIXME: dool-monitor — build failure, removed
    ;; FIXME: droidcam — build failure, removed
    ;; FIXME: dualsensectl — build failure, removed
    eilmeldung
    epr
    flclashx
    font-iosevka-nerd-fonts
    font-iosevkaterm-nerd-fonts
    font-material-design-icons
    freeze
    fsel
    ghgrab
    ght
    gmap
    gopass
    goverlay
    gowall
    handlr
    hishtory
    hxd
    hyprscratch
    instagram-cli
    jdupes
    jetm-kernel-settings
    kanata
    lazytail
    libjodycode
    limine
    localsend
    lutgen
    massren
    neo-matrix
    ;; FIXME: newsraft — build failure, removed
    oh-my-posh
    ollama
    opensoundmeter
    oports
    optiscaler
    otter-launcher
    overskride
    oyo
    par
    powerlevel10k
    proteinview
    ;; FIXME: proton-cachyos — build failure, removed
    proton-ge-custom
    protontricks
    protonup-rs
    proxypilot
    python-ascii-magic
    python-cmake-language-server
    python-neovim-remote
    python-rapidgzip
        ;; FIXME: python-sqlit — build failure, removed
    ;; FIXME: python-texicode — build failure, removed
    python-uv-dynamic-versioning
    python-vdf
    pzip
    reddix
    regex-tui
    ;; FIXME: rmlint — build failure, removed
    repeater
    resterm
    richcolors
    ;; FIXME: rofi-file-browser-extended — build failure, removed
    roomeqwizard
    rsmetrx
    rustmission
    sidecar
    simutil
    sing-box
    slsa-verifier
    songfetch
    strace-tui
    systemd-manager-tui
    tailray
    tailscale
    tanin
    taoup
    ;; FIXME: tessen — build failure, removed
    tdl
    throne
    tmmpr
    ;; FIXME: unflac — build failure, removed
    v2raya
    ;; FIXME: vicinae — build failure, removed
    watchtower
    winetricks
    wlr-which-key
    wl
    xdg-desktop-portal-termfilechooser
    xdg-ninja
    xray
    xwaylandvideobridge
    ;; FIXME: youtube-tui — build failure, removed
    ytsurf
    zapret2
    zen-browser
    ;; ── Parity push (binary packages, batch 6-10) ──
    yazi
    ruff-linter
    gitleaks-sec
    ttyd-share
    genact-activity
    ctop-monitor
    onefetch-info
    erdtree-disk
    bandwhich-net
    resvg-render
    doggo-dns
    xh-client
    lnav-log
    cpufetch-tool
    viu-viewer
    sops-secrets
    ;; FIXME: taplo-fmt — build failure, removed
    ;; FIXME: tabiew-tui — build failure, removed
    ;; FIXME: sad-editor — build failure, removed
    axctl-compositor
    grex-tool
    ;; FIXME: no-more-secrets-nms — build failure, removed
    ;; FIXME: nvtop-monitor — build failure, removed
    s-tui-stress
    ssh-to-age-key
    geoip-database-maxmind
    hermes-agent
    goose-ai
    mpdas
    ;; ── Missing from bulk-binaries ──
    gh-cli
    glow-markdown
    lazygit-bin
    zellij-bin
    ))

all-custom-packages
