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
    broot                          # Tree-based file explorer
    chromium                       # Web browser (open-source Chrome)
    epiphany                       # GNOME web browser (WebKit)
    firefox                        # Web browser
    gimp                           # GNU Image Manipulation Program
    gnome-backgrounds
    gnome-calculator
    gnome-calendar
    gnome-characters
    gnome-clocks
    gnome-color-manager
    gnome-connections
    gnome-console
    dunst                          # Notification daemon
    grim                           # Wayland screenshot tool
    hypridle                       # Hyprland idle daemon
    hyprland                       # Dynamic tiling Wayland compositor
    hyprlock                       # Hyprland screen locker
    hyprpicker                     # Hyprland color picker
    xdg-desktop-portal-hyprland
    eza                            # Modern ls replacement
    matugen
    rmpc
    rofi                           # Application launcher (X11/Wayland)
    loupe
    satty                          # Screenshot annotation tool
    slurp                          # Wayland region selector
    swayimg                        # Wayland image viewer
    wl-clipboard                   # Wayland clipboard tools (wl-copy, wl-paste)
    wlr-randr                      # Wayland output management CLI
    yazi                           # Terminal file manager
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
    wofi                           # Wayland launcher menu (like rofi)
    xdg-user-dirs-gtk
    xdg-utils
    yelp

    # ── dev (25) ───────────────────────────────────────
    cargo          # Rust package manager (includes rustc)
    rustc          # Rust compiler
    clang                          # C/C++/ObjC compiler (LLVM)
    cmake                          # Cross-platform build system
    difftastic      # Structural diff tool (understands syntax, not just lines)
    go             # Go programming language (golang compiler + tools)
    gdb                            # GNU debugger
    meson                          # Fast build system (Python/Ninja)
    ninja                          # Small build system (used by Meson)
    openblas
    luaPackages.fennel             # Lisp that compiles to Lua (luaPackages)
    git                            # Distributed version control system
    lua-language-server            # Lua language server (LSP)
    lua5_3                         # Lua 5.3 programming language
    patchelf                       # ELF binary patching tool
    neovim                         # Modern Vim fork
    nodejs                         # JavaScript runtime (Node.js)

    pipx                           # Install Python tools in isolated environments
    (python3.withPackages (ps: with ps; [
      pyperclip textual poetry orjson numpy
    ]))
    ruby                           # Ruby programming language
    subversion                     # Apache Subversion (SVN) VCS
    uv                             # Python package manager (Rust, pip replacement)
    vale                           # Prose linter (documentation style)
    # Additional common build tools (arch base-devel equivalent)
    gnumake                        # GNU Make build system
    binutils
    gcc                            # GNU C/C++ compiler
    pkg-config                     # Library dependency resolver
    autoconf                       # GNU Autoconf — portable configure scripts
    automake                       # GNU Automake — Makefile generator
    libtool                        # GNU Libtool — library support tool
    flex                           # Lexical analyzer generator (lex replacement)
    bison                          # Parser generator (yacc replacement)

    # ── network (14) ───────────────────────────────────
    curl                           # HTTP client and data transfer tool
    firewalld                      # Firewall management daemon
    networkmanager                 # Network management daemon
    bluez                          # Bluetooth protocol stack + tools
    nmap                           # Network scanner and discovery tool
    openssh                        # SSH client and server
    tailscale                      # Mesh VPN
    syncthing                      # P2P file synchronization daemon
    wget                           # HTTP download tool
    nethogs                        # Network bandwidth by process (top-like)
    networkmanagerapplet           # NetworkManager tray applet
    # cloudflare-speed-cli → nixpkgs: cloudflare-warp?
    # ufw → use firewalld above
    # proton-vpn-cli → custom/aur; omit for now

    # ── audio (3) ──────────────────────────────────────
    pipewire
    gst_all_1.gst-plugins-bad  # includes gst-plugin-pipewire
    pavucontrol

    # ── media (10) ─────────────────────────────────────
    ffmpeg                         # Multimedia converter/processor
    ffmpegthumbnailer              # Video thumbnail generator
    gst_all_1.gst-libav
    gst_all_1.gst-plugins-bad
    gst_all_1.gst-plugins-ugly
    imagemagick                    # Image manipulation suite
    mpv                            # Media player
    grilo-plugins
    rygel

    # ── fonts (2) ──────────────────────────────────────
    jetbrains-mono

    # ── gaming (9, VM: skip GPU/vulkan/xorg) ───────────
    lutris                         # Game launcher (Wine/libretro/native)
    wine                           # Windows compatibility layer
    gamescope                      # Micro-compositor for gaming (Valve)
    gamemode                       # Game performance optimization daemon
    nethack                        # Classic roguelike dungeon crawler

    # ── system (23) ────────────────────────────────────
    bottom                         # Graphical system monitor (btm)
    btop                           # Resource monitor
    htop                           # Interactive process viewer
    lsof
    lvm2
    parted
    strace                         # System call tracer
    sysstat                        # System performance monitoring (sar, iostat)
    cups
    rsync
    samba
    slirp4netns                    # User-mode networking for containers
    skopeo                         # Container image inspection tool
    system-config-printer
    zram-generator
    # xorg-server, xorg-xinit, xf86-video-amdgpu/ati → VM: not needed
    # pacman-contrib, rebuild-detector → arch-specific
    # gdm → use greetd

    # ── other (309) ────────────────────────────────────
    abduco          # Terminal session manager (like screen/tmux, but minimal)
    age             # Simple, modern file encryption tool
    age-plugin-yubikey # age plugin for YubiKey-backed encryption
    android-tools
    aria2                          # Download utility supporting multiple protocols
    asciinema
    atop
    avahi                          # mDNS/DNS-SD (zeroconf) daemon
    nssmdns                        # mDNS hostname resolution via nsswitch
    bandwhich                      # Bandwidth utilization TUI
    bat                            # cat replacement with syntax highlighting
    beets
    blender                        # 3D creation suite
    borgbackup                     # Deduplicating backup tool
    bpftrace
    carla                          # Audio plugin host (LV2/VST2/DSSI)
    cava                           # Console audio visualizer
    ccid
    yubikey-manager
    cdparanoia                     # CD audio ripping tool
    chafa                          # Terminal image viewer/probe
    chezmoi                        # Dotfile manager (declarative)
    choose                         # cut and awk replacement
    chromaprint                    # Acoustic fingerprinting library + CLI
    cliphist                       # Wayland clipboard manager
    convmv
    corectrl
    dosbox
    cowsay                         # ASCII art cow speech bubble
    cpufetch
    ctop                           # Container metrics TUI
    curlie                         # curl wrapper (httpie output)
    dash
    ddrescue
    dhcpcd
    diff-so-fancy
    difftastic                     # Structural diff tool
    direnv
    distrobox
    dive                           # Docker image layer analysis TUI
    dnsmasq                        # Lightweight DNS/DHCP/TFTP server
    doggo                          # Modern DNS client
    dos2unix
    dust
    efibootmgr
    elfutils
    enca
    entr
    erdtree
    expect
    fastfetch                      # Neofetch replacement
    fclones
    fd                             # Fast file search replacement
    figlet
    fio                            # Flexible I/O tester/benchmark
    fortune
    fping
    freerdp
    fwupd
    fzf                            # Fuzzy finder for the terminal
    genact
    geoip
    gist                           # GitHub Gist CLI tool
    git-crypt                      # Transparent git file encryption
    delta  # git-delta — nixpkgs name is 'delta'
    difftastic      # Structural diff tool (understands syntax)
    docker          # Container runtime (CLI + daemon)
    git-filter-repo                # Git repository rewriting tool
    gh                             # GitHub CLI (pull requests, issues, etc)
    gitleaks                       # Git secret scanner (pre-commit hooks)
    git-lfs                        # Git Large File Storage extension
    ghostty                        # GPU-accelerated terminal emulator
    glow
    goaccess
    gopass                         # Password manager with git/age backend
    yq-go                          # YAML/JSON/XML processor
    gptfdisk
    graphviz
    grex                           # Regex generator from examples
    gvfs
    hashcat
    helix                          # Modal text editor
    hexyl
    himalaya                       # Email CLI client (Rust)
    htmlq                          # HTML query tool (like jq for HTML)
    httpie                         # User-friendly HTTP client
    hunspellDicts.ru-ru
    hwinfo
    hyperfine                      # Command-line benchmarking tool
    id3v2
    iftop                          # Network bandwidth by connection (top-like)
    inotify-tools
    ioping
    iotop
    iperf3                         # Network bandwidth measurement tool
    isync
    iwd                            # Wi-Fi daemon (iNet Wireless Daemon)
    jc                             # JSON convert output of CLI tools
    jpegoptim
    jq                             # JSON query processor
    jujutsu                        # Git-compatible VCS (jj), simpler than git
    just                           # Command runner (like make, simpler)
    kexec-tools
    kitty                          # GPU-accelerated terminal emulator
    kmon                           # Kernel module manager TUI
    lbzip2
    lazygit                        # Terminal Git UI
    less
    libnotify
    liquidctl
    lldb
    lm_sensors
    lnav                           # Log file navigator
    lolcat                         # Rainbow text colorizer
    lowdown
    lshw
    lsp-plugins
    man-pages
    mediainfo
    libmediaart
    memtester
    miller                         # CSV/JSON/TSV data processor (mlr)
    minicom
    moreutils
    mpc                            # MPD client (Music Player Daemon)
    mpd                            # Music Player Daemon (server)
    (python3.withPackages (ps: with ps; [ mutagen ]))
    mtr                            # Network diagnostic (traceroute + ping)
    multipath-tools
    ncdu
    neomutt                        # Mutt email client fork with modern features
    nerdctl                        # Docker-compatible CLI for containerd
    nicotine-plus
    nuspell
    amdgpu_top
    ollama
    onefetch                       # Git repository summary tool
    libressl.nc
    openocd
    openrgb
    optipng
    ouch                           # Compression/decompression CLI
    parallel
    pastel                         # Color manipulation tool
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
    podman                         # Daemonless container engine
    powertop                       # Power consumption diagnosis tool
    pre-commit                     # Git pre-commit hook framework
    (python3.withPackages (ps: with ps; [ faker internetarchive ]))
    prettyping
    progress
    pv
    pwgen
    qemu
    qpwgraph
    qrencode
    rawtherapee
    rclone                         # Cloud storage sync
    recoll
    reptyr
    resvg
    ripgrep                        # Ultra-fast grep replacement
    rlwrap
    ruff                           # Python linter/formatter (Rust)
    sad
    sbctl
    schedtool
    scour
    shellcheck                     # Shell script static analyzer
    shfmt                          # Shell script formatter
    smartmontools                  # S.M.A.R.T. disk monitoring tools
    sops
    socat                          # Multipurpose socket relay tool
    sonic-visualiser
    sox
    sshfs
    sshpass
    streamlink
    s-tui                          # Terminal CPU stress + monitor
    sudo
    swappy
    tabiew
    taplo                          # TOML formatter/linter
    tcpdump                        # Packet capture/analysis CLI
    tealdeer                       # Fast tldr client (man page examples)
    telegram-desktop
    tesseract
    testdisk
    texliveBasic
    tig                            # Text-mode Git repository browser
    tmux
    toilet
    traceroute
    transmission_4
    tree
    tree-sitter                    # Parser generator for syntax highlighting
    ttyd
    tumbler
    udiskie
    ugrep
    unar
    unbound                        # Recursive DNS resolver
    unzip
    cpio
    upower                         # Power management abstraction layer
    urlscan
    urlwatch
    valgrind                       # Memory debugger/profiler
    vdirsyncer                     # CalDAV/CardDAV sync tool
    virt-manager
    virt-viewer
    viu
    vnstat                         # Network traffic monitor
    w3m
    waypipe                        # Wayland remote display (like SSH -X)
    wayvnc                         # VNC server for Wayland
    wev                            # Wayland event viewer
    wf-recorder                    # Wayland screen recorder
    which
    whois                          # Domain/WHOIS lookup client
    wireshark-cli
    wtype                          # Wayland keystroke injector
    xfsprogs
    xh                             # HTTP client like httpie
    yamllint                       # YAML file linter
    ydotool
    yt-dlp                         # YouTube/video downloader
    zathura
    zbar
    zellij                         # Terminal multiplexer
    zk
    zmap
    zoxide                         # Smarter cd command (frecency-based)
    zsh
    handlr-regex                   # Default application handler
    i3status
    i3
    inxi                           # System information script
    nano
    orca
    papers
    uwsm                           # Universal Wayland Session Manager
    vim
    wiremix                        # MPD visualizer with PipeWire

    # ── AUR equivalents in nixpkgs ─────────────────────
    act                            # Run GitHub Actions locally
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
    scc                            # Code line counter (like cloc)
    ttfautohint
    unflac
    wget2
    wlogout                        # Wayland logout screen
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
  
    xray
    niri                           # Scrolling-tiling Wayland compositor
    waybar
    buildah
    mako
    wireguard-tools
    television
    showtime
    cups-pk-helper
    goimapnotify
    iotop-c
    malcontent
    media-player-info
    snapshot
    tecla
    libsForQt5.qt5ct
    jupyter
    texlive.combined.scheme-basic
    # ── Added missing packages (nixpkgs 25.05) ──
    gh                             # GitHub CLI (pull requests, issues, etc)
    networkmanagerapplet           # NetworkManager tray applet
    noto-fonts-cjk-sans
    hunspellDicts.ru-ru
    iftop                          # Network bandwidth by connection (top-like)
    inotify-tools
    iotop
    perf
    stress-ng                      # CPU/memory/IO stress testing tool
    perlPackages.ImageExifTool
    tesseract4
    tesseract
    transmission_4-qt
    nerd-fonts.jetbrains-mono
    qemu
    qemu_kvm
    simple-scan
    sushi
    awww  # renamed from swww
    unar
    tumbler
    v2raya
    sing-box
    wget2
    wlogout                        # Wayland logout screen
    wlr-which-key
    xdg-ninja
    scc                            # Code line counter (like cloc)
    par
    jdupes
    neovim-remote
    zapret
    snapcast
    localsend
    bucklespring                   # Keyboard sound effects (IBM Model M)
    hw-probe
    google-chrome
    claude-code
    gallery-dl
    oh-my-posh
    git-extras
    rmlint
    babashka
    carapace
    python3Packages.telethon
    cmake-language-server
    fortune
    crosspipe  # helvum removed from nixpkgs
    netcat-openbsd
    pandoc
    python3Packages.ascii-magic
    python3Packages.rapidgzip
    zen-browser                    # Privacy-focused Firefox fork
    quickshell
    vicinae-bin
    bazecor
    dool
    epr
    freeze
    fsel
    ghgrab
    gmap
    gowall
    hishtory
    lutgen
    massren
    mpdas                          # Last.fm scrobbler for MPD
    mpdris2                        # MPRIS bridge for MPD
    patool
    pup
    reddix
    regex-tui
    resterm
    rustmission
    systemd-manager-tui
    tessen                         # 2FA/HOTP/TOTP CLI (Python)
    v2rayn
    witr
    youtube-tui
];
}
