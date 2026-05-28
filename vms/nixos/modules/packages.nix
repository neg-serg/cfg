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
    gnome-backgrounds              # GNOME wallpapers
    gnome-calculator               # GNOME calculator app
    gnome-calendar                 # GNOME calendar app
    gnome-characters
    gnome-clocks
    gnome-color-manager
    gnome-connections
    gnome-console
    dunst                          # Notification daemon
    grim                           # Wayland screenshot tool
    hypridle                       # Hyprland idle daemon
    #hyprland                       # Dynamic tiling Wayland compositor
    hyprlock                       # Hyprland screen locker
    hyprpicker                     # Hyprland color picker
    xdg-desktop-portal-hyprland    # XDG desktop portal backend for Hyprland
    eza                            # Modern ls replacement
    matugen                        # Material You color generator
    rmpc                           # Terminal MPD client (Rust/NCurses)
    rofi                           # Application launcher (X11/Wayland)
    loupe                          # GNOME image viewer
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
    gnome-keyring                  # GNOME Keyring (secrets storage)
    gnome-system-monitor           # GNOME task manager
    gnome-text-editor              # GNOME text editor
    gnome-tweaks                   # GNOME advanced settings
    nautilus                       # GNOME file manager
    # cosmic-greeter → replaced by greetd (DESKTOP module)
    # satty → (already above)
    # television → terminal file manager: nixpkgs has 'television'
    swayosd                        # OSD overlay for Wayland (volume/brightness)
    wofi                           # Wayland launcher menu (like rofi)
    xdg-user-dirs-gtk
    xdg-utils                      # XDG desktop integration utilities
    yelp

    #themix-theme-oomox              # broken in nixpkgs-unstable 2026-05

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
    goose                          # Open-source extensible AI agent (block/goose)
    lua-language-server            # Lua language server (LSP)
    lua5_3                         # Lua 5.3 programming language
    patchelf                       # ELF binary patching tool
    neovim                         # Modern Vim fork
    nodejs                         # JavaScript runtime (Node.js)

    #pipx                           # broken in nixpkgs-unstable 2026-05
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
    #lutris                         # broken in nixpkgs-unstable 2026-05 (openldap)
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
    atop                           # System resource monitor (advanced top)
    avahi                          # mDNS/DNS-SD (zeroconf) daemon
    nssmdns                        # mDNS hostname resolution via nsswitch
    bandwhich                      # Bandwidth utilization TUI
    bat                            # cat replacement with syntax highlighting
    beets
    blender                        # 3D creation suite
    # borgbackup (check)
    bpftrace
    carla                          # Audio plugin host (LV2/VST2/DSSI)
    cava                           # Console audio visualizer
    ccid                           # Chip/Smart Card interface driver (PC/SC)
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
    entr                           # Run command when file changes
    erdtree
    expect
    fastfetch                      # Neofetch replacement
    fclones                        # Duplicate file finder and cleaner (Rust)
    fd                             # Fast file search replacement
    figlet                         # ASCII art text banner generator
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
    graphviz                                 # not found in nixpkgs
    gvfs                           # GNOME virtual filesystem
    hashcat
    helix                          # Modal text editor
    hexyl                          # Hex viewer with colored output (Rust)
    himalaya                       # Email CLI client (Rust)
    htmlq                          # HTML query tool (like jq for HTML)
    httpie                         # User-friendly HTTP client
    hunspellDicts.ru-ru
    hwinfo                         # Hardware information probe
    hyperfine                      # Command-line benchmarking tool
    id3v2
    iftop                          # Network bandwidth by connection (top-like)
    inotify-tools                  # File event monitoring CLI tools (inotify)
    ioping
    iotop
    iperf3                         # Network bandwidth measurement tool
    isync
    iwd                            # Wi-Fi daemon (iNet Wireless Daemon)
    jc                             # JSON convert output of CLI tools
    jpegoptim                      # JPEG image optimizer
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
    lldb                           # LLVM debugger
    lm_sensors
    lnav                           # Log file navigator
    lolcat                         # Rainbow text colorizer
    lowdown
    lshw
    lsp-plugins
    man-pages
    mediainfo                      # Media file metadata viewer
    libmediaart
    memtester
    miller                         # CSV/JSON/TSV data processor (mlr)
    minicom                        # Serial communication terminal
    moreutils
    mpc                            # MPD client (Music Player Daemon)
    mpd                            # Music Player Daemon (server)
    (python3.withPackages (ps: with ps; [ mutagen ]))
    mtr                            # Network diagnostic (traceroute + ping)
    multipath-tools
    ncdu                           # NCurses disk usage analyzer
    neomutt                        # Mutt email client fork with modern features
    nerdctl                        # Docker-compatible CLI for containerd
    nicotine-plus
    nuspell
    amdgpu_top
    ollama                         # Local LLM runner (llama.cpp wrapper, Go)
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
    pngquant                       # PNG image compressor
    podman                         # Daemonless container engine
    powertop                       # Power consumption diagnosis tool
    pre-commit                     # Git pre-commit hook framework
    (python3.withPackages (ps: with ps; [ faker internetarchive ]))
    prettyping
    progress                       # Progress viewer for coreutils (C)
    pv                             # Pipe viewer (progress monitor)
    pwgen                          # Password generator
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
    sox                            # Sound eXchange (audio CLI tool)
    sshfs                          # FUSE-based SSH filesystem
    sshpass
    # streamlink (check nixpkgs)
    sudo
    swappy                         # Wayland screenshot editor (Rust)
    tabiew
    taplo                          # TOML formatter/linter
    tcpdump                        # Packet capture/analysis CLI
    tealdeer                       # Fast tldr client (man page examples)
    telegram-desktop               # Telegram messenger desktop client
    tesseract                                # not found in nixpkgs
    texliveBasic
    tig                            # Text-mode Git repository browser
    tmux
    toilet                         # ASCII art text banner (FIGlet alternative)
    traceroute
    transmission_4
    tree                           # Directory tree viewer
    tree-sitter                    # Parser generator for syntax highlighting
    ttyd
    tumbler
    udiskie
    # ugrep (check nixpkgs)
    # unar (not in nixpkgs)
    unzip
    cpio
    upower                         # Power management abstraction layer
    urlscan
    urlwatch
    valgrind                       # Memory debugger/profiler
    vdirsyncer                     # CalDAV/CardDAV sync tool
    virt-manager                   # Virtual machine manager (libvirt GUI)
    virt-viewer                    # SPICE/VNC viewer for VMs
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
    zathura                        # Minimal document viewer (PDF/EPUB/DJVU)
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
    nano                           # Simple terminal text editor
    orca
    papers
    uwsm                           # Universal Wayland Session Manager
    vim                            # Classic modal text editor
    wiremix                        # MPD visualizer with PipeWire

    # ── AUR equivalents in nixpkgs ─────────────────────
    act                            # Run GitHub Actions locally
    advancecomp
    claude-code
    cmake-language-server
    dcfldd
    ddccontrol                     # DDC/CI monitor control (brightness, input, etc.)
    dualsensectl                   # DualSense controller CLI tool
    gallery-dl                     # Image gallery downloader (Python)
    git-extras
    google-chrome
    hw-probe                       # Hardware probe and upload to linux-hardware.org
    jdupes
    localsend
    neovim-remote
    newsraft
    oh-my-posh
    par                            # Paragraph reformatter (text formatting CLI)
    patool
    python3Packages.ascii-magic
    python3Packages.rapidgzip
    scc                            # Code line counter (like cloc)
    ttfautohint
    unflac
    wget2
    wlogout                        # Wayland logout screen
    wlr-which-key
    xdg-ninja                      # Fix XDG base directory compliance for apps

    # ── AUR: no nixpkgs equivalent → custom or skipped ─
    # amdgpu-vulkan-switcher-git → not in nixpkgs (GPU-specific)
    # amdvlk-bin, lib32-amdvlk-bin → not available
    # optiscaler-universal → not available
    # babashka-bin → available as 'babashka'
    # carapace-bin → 'carapace'
    # aliae-bin → not available
    # eilmeldung-bin → not available
    ## flclashx-bin → not available
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
    ## no-more-secrets → not available
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
        ytsurf                    # custom overlay
    # bazecor → not available
        xray                      # custom overlay
        v2raya                    # custom overlay
        zapret2                   # custom overlay

    # ── Additional nixpkgs AUR matches ─────────────────
    babashka
    carapace
    v2ray
    raysession                     # JACK audio session manager
    rmlint                         # Duplicate file finder (C)
    sing-box                       # Universal proxy platform (Go)
    niri                           # Scrolling-tiling Wayland compositor
    waybar
    buildah
    mako                           # Wayland notification daemon
    wireguard-tools                # WireGuard VPN CLI tools
    television                     # Terminal television (TUI tool?)
    showtime
    cups-pk-helper
    goimapnotify
    iotop-c
    malcontent                     # Parental controls for Linux
    media-player-info
    snapshot
    tecla
    libsForQt5.qt5ct  # FIXME: check if exists
    jupyter
    texlive.combined.scheme-basic
    # ── Added missing packages (nixpkgs 25.05) ──
    noto-fonts-cjk-sans
    hunspellDicts.ru-ru
    iotop
    perf
    stress-ng                      # CPU/memory/IO stress testing tool
    perlPackages.ImageExifTool
    tesseract4
    nerd-fonts.jetbrains-mono
    qemu
    qemu_kvm
    simple-scan                    # Document scanner GUI
    sushi                          # GNOME file previewer (quick preview)
    awww  # renamed from swww
    # unar (not in nixpkgs)
    wget2
    wlr-which-key
    jdupes
    neovim-remote
    zapret
    snapcast                       # Synchronous multi-room audio player
    localsend
    bucklespring                   # Keyboard sound effects (IBM Model M)
    google-chrome
    claude-code
    oh-my-posh
    git-extras
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
    quickshell                     # QtQuick-based Wayland shell environment
    qt6.qtwayland                 # Qt6 Wayland platform plugin (required by quickshell-overview)
    # quickshell-overview-git → QML-only (files managed via dotfiles/quickshell/overview/)
    vicinae-bin                    # Qt6 launcher/dashboard (prebuilt binary)
    bazecor                        # Dygma Raise keyboard configurator (GUI)
    dool
    epr                            # Terminal EPUB reader (Rust)
    freeze
    fsel
    ghgrab
    gmap
    gowall
    hishtory                       # Sync shell history across machines (end-to-end encrypted)
    lutgen
    massren                        # Mass file renamer (Rust)
    mpdas                          # Last.fm scrobbler for MPD
    mpdris2                        # MPRIS bridge for MPD
    patool
    pup                            # HTML parser CLI (jq for HTML, Go)
    reddix
    regex-tui                      # Regex tester/editor (TUI, Rust)
    resterm
    rustmission                    # Rust BitTorrent client (TUI)
    systemd-manager-tui
    tessen                         # 2FA/HOTP/TOTP CLI (Python)
    v2rayn                         # V2Ray Windows GUI client
    witr                           # WireGuard interactive TUI configurator
    youtube-tui

    # ── Parity push: packages from CachyOS now in nixpkgs ──
    python3Packages.pip             # Python package installer (pip)
    #pipx                            # Run Python applications in isolated environments
    python3Packages.pysocks          # SOCKS proxy client for Python
    python3Packages.transformers     # HuggingFace Transformers (ML models)
    btrfs-progs                     # Btrfs filesystem utilities
    dosfstools                      # DOS/FAT filesystem utilities
    #etckeeper  # FIXME: not in nixpkgs                       # Version control for /etc directory
    gst_all_1.gst-libav             # GStreamer libav plugin
    gst_all_1.gst-plugins-ugly      # GStreamer ugly plugins
    unbound                         # Validating recursive DNS resolver
    streamlink                      # Extract streams from various services
    testdisk                        # Data recovery utilities
    sbcl                            # Steel Bank Common Lisp
    supercollider                   # Audio synthesis engine and programming language
    transmission_4                  # BitTorrent client (CLI + daemon)
    ugrep                           # Ultra-fast grep with interactive query UI
    pass                            # Password store (Unix password manager)
    grafana                         # Analytics and monitoring dashboard
    libvirt                         # Virtualization API and management tools
    cage                            # Kiosk compositor for Wayland
    networkmanagerapplet            # NetworkManager system tray applet
    #easyeffects  # FIXME: may need pipewire enabled                     # Audio effects for PipeWire
    #xwaylandvideobridge  # FIXME: removed from nixpkgs (KDE5 EOL)             # XWayland to Wayland video bridge
    kdePackages.kate                 # KDE advanced text editor
    kdePackages.konsole              # KDE terminal emulator
    kdePackages.ark                  # KDE archive manager
    nicotine-plus                   # Graphical Soulseek client
    grex                            # Regex generator from test cases
    cdrtools                        # CD/DVD/BluRay recording tools
    qemu_kvm                        # QEMU with KVM acceleration
    linuxKernel.packages.linux_6_12.cpupower                        # Linux kernel CPU frequency management
    lshw                            # Hardware lister (detailed system info)
    #sc3-plugins  # FIXME: part of supercollider                     # SuperCollider plugins

    ## ── Parity push: custom overlay packages ──
    ##aliae-bin  # FIXME: no GitHub releases                       # Cross-shell aliases manager
    #antigravity-tools-bin           # Antigravity tools collection
    #eilmeldung-bin                  # Eilmeldung notification tool
    ##flclashx-bin                    # FlClashX proxy client
    #gitlogue                        # Git history analysis tool
    ##hxd                             # Hex dump tool
    ##hyprscratch                     # Hyprland scratchpad tool
    #instagram-cli                   # Instagram CLI tool
    ##kanata                          # Keyboard remapper
    #lazytail                        # Lazy log tail viewer
    #neo-matrix                      # Digital rain from The Matrix
    ##no-more-secrets                  # Sneakers decrypting text effect (nms)
    #opencode                        # Open-source AI coding CLI
    #oports-git                      # Open port scanner
    #otter-launcher                  # Otter application launcher
    #oyo                             # Oyo utility tool
    #pipemixer                       # PipeWire audio mixer
    #qman                            # Quick man page viewer
    #rofi-file-browser-extended      # Extended file browser for rofi
    ##s-tui                           # CPU stress and monitoring TUI
    #strace-tui                      # TUI frontend for strace
    #tdl                             # Telegram downloader
    ##yandex-browser  # FIXME: unfree, deb download                  # Yandex Browser (unfree)
    ##bottles  # FIXME: AppImage not available for download                         # Wine prefix manager (AppImage)
    #cloudflare-speedtest            # Cloudflare speed test CLI
    #droidcam                        # Android phone as webcam
    #goverlay                        # MangoHud/vkBasalt config GUI
    #hyprquickframe                  # Hyprland quick frame capture
    ##opensoundmeter                   # Audio measurement tool
    ##proton-ge-custom                # Custom Proton-GE build
    #protonup-rs                     # Proton-GE installer (Rust)
    #steam                           # Steam gaming platform (unfree)
    ## unar (unarchiver) — not in nixpkgs; use 'lsar' from 'unar' package
];
}
    ## amdvlk                                 # AMD Vulkan driver (open source, AMDGPU)
    ## dkms (not in nixpkgs)
    ## etckeeper (not in nixpkgs)
    ## overlay packages moved to main list below
    ## (python section only)
    ## fortune-mod overlay
    ## hyprpolkitagent overlay
    ## libpulseaudio overlay
    ## python3Packages.faker (check)
    ## python3Packages.internetarchive (check)
    ## python3Packages.mutagen (check)
    ## python3Packages.numpy (check)
    ## python3Packages.orjson (check)
    ## python3Packages.poetry (check)
    ## python3Packages.pyperclip (check)
    ## python3Packages.textual (check)
    ## rofi-calc                              (check) # Rofi calculator plugin
    ## songfetch                              (check) # Song info fetcher (MPD/Last.fm, Rust)
    ## tesseract-data-eng                     # Tesseract English language data
    ## tesseract-data-rus                     # Tesseract Russian language data
    ## transmission (in python section)
    ## turbostat                              # Intel CPU turbo/energy status monitor
    ## fortune-mod (in python section)
    ## graphviz (in python section)
    ## hyprpolkitagent (in python section)
    ## libpulseaudio (in python section)
    ## nvtop (in python section)
    ## pass (in python section)
    ## perl-Image-ExifTool (in python section)
    ## tesseract (in python section)
    ## transmission (in python section)
    ## restic (check nixpkgs)
    ## s-tui (overlay needed)
