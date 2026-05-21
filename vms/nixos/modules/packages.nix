{ config, pkgs, lib, ... }:

let
  inherit (lib) mkIf mkMerge;
in
{
  environment.systemPackages = with pkgs; [

    # ── base (8) ──────────────────────────────────────
    linux-firmware
    # base-devel → no direct equivalent; stdenv + build essentials below
    # limine → use systemd-boot (in VM)
    # linux, linux-headers → nixpkgs provides kernel automatically

    # ── desktop (64) ──────────────────────────────────
    broot
    chromium
    epiphany
    firefox
    gimp
    gnome-backgrounds
    gnome-calculator
    gnome-calendar
    gnome-characters
    gnome-clocks
    gnome-color-manager
    gnome-connections
    gnome-console
    dunst
    grim
    hypridle
    hyprland
    hyprlock
    hyprpicker
    xdg-desktop-portal-hyprland
    eza
    matugen
    rmpc
    rofi
    loupe
    satty
    slurp
    swayimg
    wl-clipboard
    wlr-randr
    yazi
    # ark, gnome-contacts, gnome-control-center, gnome-disk-utility,
    # gnome-font-viewer, gnome-keyring, gnome-logs, gnome-maps, gnome-menus,
    # gnome-music, gnome-remote-desktop, gnome-session, gnome-settings-daemon,
    # gnome-shell, gnome-software, gnome-system-monitor, gnome-text-editor,
    # gnome-tour, gnome-tweaks, gnome-user-docs, gnome-user-share, gnome-weather,
    # nautilus, simple-scan, sushi
    # → Minimal VM: omit full GNOME desktop; Hyprland-only target
    gnome-control-center
    gnome-disk-utility
    gnome-keyring
    gnome-system-monitor
    gnome-text-editor
    gnome-tweaks
    nautilus
    # cosmic-greeter → replaced by greetd (DESKTOP module)
    # satty → (already above)
    # television → terminal file manager: nixpkgs has 'television'
    swayosd
    wofi
    xdg-user-dirs-gtk
    xdg-utils
    yelp

    # ── dev (25) ───────────────────────────────────────
    clang
    cmake
    gdb
    meson
    ninja
    openblas
    luaPackages.fennel
    git
    lua-language-server
    lua5_3
    patchelf
    neovim
    nodejs

    pipx
    (python3.withPackages (ps: with ps; [
      pyperclip textual poetry orjson numpy
    ]))
    ruby
    subversion
    uv
    vale
    # Additional common build tools (arch base-devel equivalent)
    gnumake
    binutils
    gcc
    pkg-config
    autoconf
    automake
    libtool
    flex
    bison

    # ── network (14) ───────────────────────────────────
    curl
    firewalld
    networkmanager
    bluez
    nmap
    openssh
    tailscale
    wget
    nethogs
    networkmanagerapplet
    # cloudflare-speed-cli → nixpkgs: cloudflare-warp?
    # ufw → use firewalld above
    # proton-vpn-cli → custom/aur; omit for now

    # ── audio (3) ──────────────────────────────────────
    pipewire
    gst_all_1.gst-plugins-bad  # includes gst-plugin-pipewire
    pavucontrol

    # ── media (10) ─────────────────────────────────────
    ffmpeg
    ffmpegthumbnailer
    gst_all_1.gst-libav
    gst_all_1.gst-plugins-bad
    gst_all_1.gst-plugins-ugly
    imagemagick
    mpv
    grilo-plugins
    rygel

    # ── fonts (2) ──────────────────────────────────────
    jetbrains-mono

    # ── gaming (9, VM: skip GPU/vulkan/xorg) ───────────
    lutris
    wine
    gamescope
    gamemode
    nethack

    # ── system (23) ────────────────────────────────────
    bottom
    btop
    htop
    lsof
    lvm2
    parted
    strace
    sysstat
    cups
    rsync
    samba
    slirp4netns
    skopeo
    system-config-printer
    zram-generator
    # xorg-server, xorg-xinit, xf86-video-amdgpu/ati → VM: not needed
    # pacman-contrib, rebuild-detector → arch-specific
    # gdm → use greetd

    # ── other (309) ────────────────────────────────────
    abduco
    age
    age-plugin-yubikey
    android-tools
    aria2
    asciinema
    atop
    avahi
    nssmdns
    bandwhich
    bat
    beets
    blender
    borgbackup
    bpftrace
    carla
    cava
    ccid
    yubikey-manager
    cdparanoia
    chafa
    chezmoi
    choose
    chromaprint
    cliphist
    convmv
    corectrl
    dosbox
    cowsay
    cpufetch
    ctop
    curlie
    dash
    ddrescue
    dhcpcd
    diff-so-fancy
    difftastic
    direnv
    distrobox
    dive
    dnsmasq
    doggo
    dos2unix
    dust
    efibootmgr
    elfutils
    enca
    entr
    erdtree
    expect
    fastfetch
    fclones
    fd
    figlet
    fio
    fortune
    fping
    freerdp
    fwupd
    fzf
    genact
    geoip
    gist
    git-crypt
    delta  # git-delta — nixpkgs name is 'delta'
    git-filter-repo
    gh
    gitleaks
    git-lfs
    ghostty
    glow
    goaccess
    gopass
    yq-go
    gptfdisk
    graphviz
    grex
    gvfs
    hashcat
    helix
    hexyl
    himalaya
    htmlq
    httpie
    hunspellDicts.ru-ru
    hwinfo
    hyperfine
    id3v2
    iftop
    inotify-tools
    ioping
    iotop
    iperf3
    isync
    iwd
    jc
    jpegoptim
    jq
    jujutsu
    just
    kexec-tools
    kitty
    kmon
    lbzip2
    less
    libnotify
    liquidctl
    lldb
    lm_sensors
    lnav
    lolcat
    lowdown
    lshw
    lsp-plugins
    man-pages
    mediainfo
    libmediaart
    memtester
    miller
    minicom
    moreutils
    mpc
    mpd
    (python3.withPackages (ps: with ps; [ mutagen ]))
    mtr
    multipath-tools
    ncdu
    neomutt
    nerdctl
    nicotine-plus
    nuspell
    amdgpu_top
    ollama
    onefetch
    libressl.nc
    openocd
    openrgb
    optipng
    ouch
    parallel
    pastel
    pbzip2
    pcmanfm
    pcsc-tools
    perf-tools
    perlPackages.ImageExifTool
    pgcli
    picard
    pigz
    plocate
    pngquant
    podman
    powertop
    pre-commit
    (python3.withPackages (ps: with ps; [ faker internetarchive ]))
    prettyping
    progress
    pv
    pwgen
    qemu
    qpwgraph
    qrencode
    rawtherapee
    rclone
    recoll
    reptyr
    resvg
    ripgrep
    rlwrap
    ruff
    sad
    sbctl
    schedtool
    scour
    shellcheck
    shfmt
    smartmontools
    sops
    socat
    sonic-visualiser
    sox
    sshfs
    sshpass
    streamlink
    s-tui
    sudo
    swappy
    tabiew
    taplo
    tcpdump
    tealdeer
    telegram-desktop
    tesseract
    testdisk
    texliveBasic
    tig
    tmux
    toilet
    traceroute
    transmission_4
    tree
    tree-sitter
    ttyd
    tumbler
    udiskie
    ugrep
    unar
    unbound
    unzip
    cpio
    upower
    urlscan
    urlwatch
    valgrind
    vdirsyncer
    virt-manager
    virt-viewer
    viu
    vnstat
    w3m
    waypipe
    wayvnc
    wev
    wf-recorder
    which
    whois
    wireshark-cli
    wtype
    xfsprogs
    xh
    yamllint
    ydotool
    yt-dlp
    zathura
    zbar
    zellij
    zk
    zmap
    zoxide
    zsh
    handlr-regex
    i3status
    i3
    inxi
    nano
    orca
    papers
    uwsm
    vim
    wiremix

    # ── AUR equivalents in nixpkgs ─────────────────────
    act
    advancecomp
    claude-code
    cmake-language-server
    dcfldd
    ddccontrol
    dualsensectl
    gallery-dl
    git-extras
    google-chrome
    hw-probe
    jdupes
    localsend
    neovim-remote
    newsraft
    oh-my-posh
    par
    patool
    python3Packages.ascii-magic
    python3Packages.rapidgzip
    scc
    ttfautohint
    unflac
    wget2
    wlogout
    wlr-which-key
    xdg-ninja

    # ── AUR: no nixpkgs equivalent → custom or skipped ─
    # amdgpu-vulkan-switcher-git → not in nixpkgs (GPU-specific)
    # amdvlk-bin, lib32-amdvlk-bin → not available
    # optiscaler-universal → not available
    # babashka-bin → available as 'babashka'
    # carapace-bin → 'carapace'
    # aliae-bin → not available
    # eilmeldung-bin → not available
    # flclashx-bin → not available
    # v2raya-bin → 'v2raya' (available)
    # v2rayn-bin → not available
    # v2ray → 'v2ray' (available)
    # fsel-bin → not available
    # epr-git → not available
    # freeze-bin → not available
    # ghgrab-bin → not available
    # gmap-bin → not available
    # gowall-bin → not available
    # hishtory-bin → not available
    # hxd → not available
    # hyprscratch → not available
    # instagram-cli → not available
    # lazytail-bin → not available
    # lutgen-bin → not available
    # massren → not available
    # mpdris2-git → not available
    # mpdas → not available
    # no-more-secrets → not available
    # otter-launcher → not available
    # oports-git → not available
    # oyo → not available
    # paru → arch-specific (AUR helper), skip
    # paru-debug → skip
    # pipemixer-git → not available
    # pup-bin → not available
    # quickshell → external (custom build)
    # reddix-bin → not available
    # repeater-bin → not available
    # regex-tui → not available
    # raysession → 'raysession' available in nixpkgs
    # resterm-bin → not available
    # rmlint → 'rmlint' available in nixpkgs
    # rofi-file-browser-extended-git → not available
    # rustmission → not available
    # songfetch → not available
    # simutil-bin → not available
    # sing-box-bin → 'sing-box' available in nixpkgs
    # strace-tui-bin → not available
    # systemd-manager-tui → not available
    # tanin-git → not available
    # tessen → not available
    # tmmpr → not available
    # watchtower-bin → not available
    # witr-bin → not available
    # youtube-tui → not available
    # ytsurf → not available
    # bazecor → not available
    # python-telethon → 'python3Packages.telethon' available
    # zapret2 → custom (network module)
    # vicinae-bin → external (custom build)

    # ── Additional nixpkgs AUR matches ─────────────────
    babashka
    carapace
    v2raya
    v2ray
    raysession
    rmlint
    sing-box
  
    # ── Added missing packages (nixpkgs 25.05) ──
    gh
    networkmanagerapplet
    noto-fonts-cjk-sans
    hunspellDicts.ru-ru
    iftop
    inotify-tools
    iotop
    perf
    stress-ng
    perlPackages.ImageExifTool
    tesseract4
    tesseract
    transmission_4-qt
    nerd-fonts.jetbrains-mono
    qemu
    qemu_kvm
    simple-scan
    sushi
    swww
    unar
    tumbler
    v2raya
    sing-box
    wget2
    wlogout
    wlr-which-key
    xdg-ninja
    scc
    par
    jdupes
    neovim-remote
    zapret
    snapcast
    localsend
    bucklespring
    hw-probe
    google-chrome
    claude-code
    gallery-dl
    oh-my-posh
    git-extras
    rmlint
    babashka
    carapace
    bucklespring
    python3Packages.telethon
    cmake-language-server
];
}
