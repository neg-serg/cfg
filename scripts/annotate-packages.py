#!/usr/bin/env python3
"""
Annotate package lists with descriptions in Salt (YAML), NixOS (Nix), and Guix (Scheme).

Reads package names from each config file and adds inline comments with descriptions.
Skips packages that already have comments.

Usage:
  python3 scripts/annotate-packages.py              # all three configs
  python3 scripts/annotate-packages.py --nixos       # NixOS only
  python3 scripts/annotate-packages.py --salt        # Salt only
  python3 scripts/annotate-packages.py --guix        # Guix only
"""

import re, argparse
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent

# ─── Package descriptions ───
DESC = {
    # ── core utils ──
    "eza": "Modern ls replacement (Rust)",
    "fd": "Fast file search replacement (Rust)",
    "ripgrep": "Ultra-fast grep replacement (Rust)",
    "bat": "cat replacement with syntax highlighting (Rust)",
    "delta": "Git diff viewer with syntax highlighting",
    "git-delta": "Git diff viewer with syntax highlighting",
    "difftastic": "Structural diff tool (understands syntax)",
    "jujutsu": "Git-compatible VCS (jj), simpler than git",
    "zoxide": "Smarter cd command (frecency-based)",
    "fzf": "Fuzzy finder for terminal",
    "tealdeer": "Fast tldr client (man examples)",
    "just": "Command runner like make, simpler (Rust)",
    "yazi": "Terminal file manager (Rust)",
    "chezmoi": "Dotfile manager (declarative, Go)",
    "gopass": "Password manager with git/age backend (Go)",
    "age": "Simple modern file encryption (Go)",
    "broot": "Tree-based file explorer (Rust)",
    "btop": "Resource monitor (C++)",
    "htop": "Interactive process viewer",
    "fastfetch": "Neofetch replacement (C)",
    "helix": "Modal text editor (Rust)",
    "neovim": "Modern Vim fork (Lua-first)",
    "lazygit": "Terminal Git UI (Go)",
    "ouch": "Compression and decompression CLI (Rust)",
    "onefetch": "Git repository summary tool (Rust)",
    "pastel": "Color manipulation tool (Rust)",
    "cargo": "Rust package manager (includes rustc)",
    "rust": "Rust programming language (cargo + rustc)",
    "go": "Go programming language compiler + tools",
    "docker": "Container runtime CLI + daemon",
    "podman": "Daemonless container engine (Go)",
    "nerdctl": "Docker-compatible CLI for containerd (Go)",
    "zellij": "Terminal multiplexer (Rust)",
    "taplo": "TOML formatter and linter (Rust)",
    "watchexec": "File watcher that runs commands (Rust)",
    "jq": "JSON query processor (C)",
    "yq-go": "YAML/JSON/XML processor (Go)",
    "miller": "CSV/JSON/TSV data processor (Go)",
    "scc": "Code line counter like cloc (Go)",
    "shfmt": "Shell script formatter (Go)",
    "shellcheck": "Shell script static analyzer (Haskell)",
    "pre-commit": "Git pre-commit hook framework (Python)",
    "ruff": "Python linter and formatter (Rust)",
    "handlr-regex": "Default application handler (Rust)",
    "handlr": "Default application handler (Rust)",
    "uwsm": "Universal Wayland Session Manager",
    "cliphist": "Wayland clipboard manager (Go)",
    "wl-clipboard": "Wayland clipboard tools (wl-copy, wl-paste)",
    "wev": "Wayland event viewer",
    "wtype": "Wayland keystroke injector",
    "grim": "Wayland screenshot tool",
    "slurp": "Wayland region selector",
    "swayimg": "Wayland image viewer",
    "swappy": "Wayland screenshot editor (Rust)",
    "satty": "Screenshot annotation tool (Rust)",
    "wf-recorder": "Wayland screen recorder",
    "wlogout": "Wayland logout screen",
    "wofi": "Wayland launcher menu like rofi",
    "rofi": "Application launcher (X11/Wayland)",
    "dunst": "Notification daemon",
    "mako": "Wayland notification daemon",
    "waypipe": "Wayland remote display like SSH -X",
    "wayvnc": "VNC server for Wayland",
    "wlr-randr": "Wayland output management CLI",
    "hypridle": "Hyprland idle daemon",
    "hyprlock": "Hyprland screen locker",
    "hyprpicker": "Hyprland color picker",
    "hyprland": "Dynamic tiling Wayland compositor",
    "hyprcursor": "Hyprland cursor theme support",
    "greetd": "Login greeter daemon (display manager)",
    "tuigreet": "TUI greeter for greetd",
    "quickshell": "QtQuick-based Wayland shell environment",
    "niri": "Scrolling-tiling Wayland compositor",
    "ghostty": "GPU-accelerated terminal emulator",
    "kitty": "GPU-accelerated terminal emulator",
    "alacritty": "GPU-accelerated terminal emulator (Rust)",
    "wezterm": "GPU-accelerated terminal emulator",
    "foot": "Wayland-native terminal emulator",
    "konsole": "KDE terminal emulator",
    "kate": "KDE advanced text editor",
    "mpv": "Media player (C)",
    "ffmpeg": "Multimedia converter and processor",
    "yt-dlp": "YouTube/video downloader",
    "imagemagick": "Image manipulation suite",
    "imv": "Image viewer for Wayland/X11",
    "feh": "Image viewer and wallpaper setter",
    "rclone": "Cloud storage sync (Go)",
    "borgbackup": "Deduplicating backup tool (Python/C)",
    "borg": "Deduplicating backup tool (Python/C)",
    "restic": "Fast backup program (Go)",
    "skopeo": "Container image inspection tool (Go)",
    "slirp4netns": "User-mode networking for containers",
    "tailscale": "Mesh VPN (Go)",
    "unbound": "Recursive DNS resolver (C)",
    "avahi": "mDNS/DNS-SD zeroconf daemon",
    "nssmdns": "mDNS hostname resolution via nsswitch",
    "iwd": "Wi-Fi daemon (iNet Wireless Daemon)",
    "dnsmasq": "Lightweight DNS/DHCP/TFTP server",
    "networkmanager": "Network management daemon",
    "kmon": "Kernel module manager TUI (Rust)",
    "lnav": "Log file navigator (C++)",
    "ctop": "Container metrics TUI (Go)",
    "dive": "Docker image layer analysis TUI (Go)",
    "s-tui": "Terminal CPU stress + monitor (Python)",
    "bottom": "Graphical system monitor btm (Rust)",
    "gping": "Ping with graph display (Rust)",
    "procs": "ps replacement (Rust)",
    "mpc": "MPD client (Music Player Daemon)",
    "mpd": "Music Player Daemon (server)",
    "mpdas": "Last.fm scrobbler for MPD",
    "patchelf": "ELF binary patching tool",
    "strace": "System call tracer",
    "valgrind": "Memory debugger and profiler",
    "gdb": "GNU debugger",
    "lldb": "LLVM debugger",
    "clang": "C/C++/ObjC compiler (LLVM)",
    "gcc": "GNU C/C++ compiler",
    "gcc-toolchain": "GNU C/C++ compiler and toolchain",
    "cmake": "Cross-platform build system",
    "meson": "Fast build system (Python/Ninja)",
    "ninja": "Small build system used by Meson",
    "gnumake": "GNU Make build system",
    "make": "GNU Make build system",
    "autoconf": "GNU Autoconf portable configure scripts",
    "automake": "GNU Automake Makefile generator",
    "libtool": "GNU Libtool library support tool",
    "pkg-config": "Library dependency resolver",
    "bison": "Parser generator (yacc replacement)",
    "flex": "Lexical analyzer generator (lex replacement)",
    "openssh": "SSH client and server",
    "openssl": "SSL/TLS cryptography library plus CLI",
    "curl": "HTTP client and data transfer tool",
    "wget": "HTTP download tool",
    "nmap": "Network scanner and discovery tool",
    "tcpdump": "Packet capture and analysis CLI",
    "socat": "Multipurpose socket relay tool",
    "iperf": "Network bandwidth measurement tool",
    "iperf3": "Network bandwidth measurement tool",
    "mtr": "Network diagnostic (traceroute + ping)",
    "whois": "Domain and WHOIS lookup client",
    "networkmanagerapplet": "NetworkManager tray applet",
    "firewalld": "Firewall management daemon",
    "bluez": "Bluetooth protocol stack and tools",
    "upower": "Power management abstraction layer",
    "powertop": "Power consumption diagnosis tool",
    "inxi": "System information script",
    "fio": "Flexible I/O tester/benchmark",
    "stress-ng": "CPU/memory/IO stress testing tool",
    "hyperfine": "Command-line benchmarking tool (Rust)",
    "sysstat": "System performance monitoring (sar, iostat)",
    "vnstat": "Network traffic monitor daemon and CLI",
    "lnav": "Log file navigator (C++)",
    "iftop": "Network bandwidth by connection (top-like)",
    "nethogs": "Network bandwidth by process (top-like)",
    "lolcat": "Rainbow text colorizer (Ruby)",
    "pciutils": "PCI bus utilities (lspci)",
    "usbutils": "USB device utilities (lsusb)",
    "smartmontools": "S.M.A.R.T. disk monitoring tools",
    "nodejs": "JavaScript runtime (Node.js)",
    "node": "JavaScript runtime (Node.js)",
    "ruby": "Ruby programming language",
    "python": "Python 3 programming language",
    "python-pip": "Python package installer (pip)",
    "python3": "Python 3 programming language",
    "uv": "Fast Python/Rust package manager (Rust)",
    "vale": "Prose linter (documentation style checker)",
    "lua-language-server": "Lua language server (LSP)",
    "lua5_3": "Lua 5.3 programming language",
    "fennel": "Lisp that compiles to Lua",
    "pipx": "Install Python tools in isolated environments",
    "git": "Distributed version control system",
    "tig": "Text-mode Git repository browser (ncurses)",
    "git-crypt": "Transparent git file encryption",
    "git-lfs": "Git Large File Storage extension",
    "git-filter-repo": "Git repository history rewriting tool",
    "gh": "GitHub CLI (pull requests, issues, releases)",
    "gitleaks": "Git secret scanner",
    "gist": "GitHub Gist CLI tool",
    "subversion": "Apache Subversion VCS",
    "act": "Run GitHub Actions locally (Go)",
    "tree-sitter": "Parser generator for syntax highlighting",
    "yamllint": "YAML file linter",
    "python-yamllint": "YAML file linter",
    "choose": "cut and awk replacement (Rust)",
    "grex": "Regex generator from examples (Rust)",
    "htmlq": "HTML query tool like jq for HTML (Rust)",
    "dog": "DNS lookup tool (Rust)",
    "doggo": "Modern DNS client (Go)",
    "xh": "HTTP client like httpie (Rust)",
    "httpie": "User-friendly HTTP client (Python)",
    "websocat": "WebSocket client and server (Rust)",
    "himalaya": "Email CLI client (Rust)",
    "neomutt": "Mutt email client fork with modern features",
    "mutt": "Email client (text-based)",
    "notmuch": "Fast email indexer and search",
    "mbsync": "Mailbox synchronizer (IMAP/Maildir) aka isync",
    "msmtp": "SMTP mail client",
    "vdirsyncer": "CalDAV/CardDAV sync tool (Python)",
    "khal": "CalDAV calendar CLI client (Python)",
    "tessen": "2FA/HOTP/TOTP CLI tool (Python)",
    "imapnotify": "IMAP idle push notification",
    "bucklespring": "Keyboard sound effects (IBM Model M)",
    "cava": "Console audio visualizer",
    "cdparanoia": "CD audio ripping tool",
    "chafa": "Terminal image viewer and probe",
    "chromaprint": "Acoustic fingerprinting library + CLI",
    "aria2": "Download utility (multi-protocol)",
    "atop": "System resource monitor (advanced top)",
    "entr": "Run command when file changes",
    "fclones": "Duplicate file finder and cleaner (Rust)",
    "figlet": "ASCII art text banner generator",
    "hexyl": "Hex viewer with colored output (Rust)",
    "hwinfo": "Hardware information probe",
    "inotify-tools": "File event monitoring CLI tools (inotify)",
    "jpegoptim": "JPEG image optimizer",
    "mandoc": "Man page formatter/reader (BSD)",
    "mediainfo": "Media file metadata viewer",
    "minicom": "Serial communication terminal",
    "nano": "Simple terminal text editor",
    "ncdu": "NCurses disk usage analyzer",
    "pngquant": "PNG image compressor",
    "progress": "Progress viewer for coreutils (C)",
    "pv": "Pipe viewer (progress monitor)",
    "pwgen": "Password generator",
    "sox": "Sound eXchange (audio CLI tool)",
    "sshfs": "FUSE-based SSH filesystem",
    "toilet": "ASCII art text banner (FIGlet alternative)",
    "tree": "Directory tree viewer",
    "ugrep": "Ultra-fast grep with TUI (C++)",
    "vim": "Classic modal text editor",
    "zathura": "Minimal document viewer (PDF/EPUB/DJVU)",
    "blender": "3D creation suite",
    "cowsay": "ASCII art cow speech bubble",
    "chromium": "Web browser (open-source Chrome)",
    "icecat": "GNU IceCat (free software Firefox fork)",
    "ungoogled-chromium-wayland": "Chromium without Google services (Wayland)",
    "firefox": "Web browser",
    "zen-browser": "Privacy-focused Firefox fork",
    "gimp": "GNU Image Manipulation Program",
    "obs": "Open Broadcaster Studio (streaming/recording)",
    "lutris": "Game launcher (Wine/libretro/native)",
    "wine": "Windows compatibility layer",
    "wine-staging": "Wine with staging patches",
    "gamescope": "Micro-compositor for gaming (Valve)",
    "gamemode": "Game performance optimization daemon",
    "mangohud": "Game overlay (FPS, temps, etc.)",
    "nethack": "Classic roguelike dungeon crawler",
    "steam": "Steam gaming platform",
    "proton-ge-custom": "Proton GE (Wine fork for Steam)",
    "protontricks": "Winetricks for Proton",
    "qbittorrent": "BitTorrent client (Qt)",
    "libreoffice": "Office suite",
    "keepassxc": "Password manager (Qt, KeePass compatible)",
    "kdenlive": "Video editor (KDE)",
    "audacity": "Audio editor",
    "nextcloud-client": "Nextcloud sync client",
    "telegram-desktop": "Telegram messenger desktop client",
    "icedove": "Email client (Thunderbird fork)",
    "virt-manager": "Virtual machine manager (libvirt GUI)",
    "virt-viewer": "SPICE/VNC viewer for VMs",
    "dualsensectl": "DualSense controller CLI tool",
    "hw-probe": "Hardware probe and upload to linux-hardware.org",
    "raysession": "JACK audio session manager",
    "rmlint": "Duplicate file finder (C)",
    "tor": "Tor anonymous network daemon",
    "torsocks": "Tor SOCKS proxy wrapper",
    "wireguard-tools": "WireGuard VPN CLI tools",
    "openvpn": "OpenVPN client/server",
    "v4l-utils": "Video4Linux utilities (webcam control)",
    "wireplumber": "PipeWire session manager (replaces wireplumber)",
    "playerctl": "Media player controller (MPRIS CLI)",
    "brightnessctl": "Backlight/brightness control CLI",
    "gallery-dl": "Image gallery downloader (Python)",
    "syncthing": "P2P file synchronization daemon (Go)",
    "flatpak": "Sandboxed application manager",
    "xrandr": "X11 RandR display configuration tool",
    "xdg-utils": "XDG desktop integration utilities",
    "xdg-desktop-portal-hyprland": "XDG desktop portal backend for Hyprland",
    "xdg-desktop-portal-gtk": "XDG desktop portal backend for GTK",
    "ccid": "Chip/Smart Card interface driver (PC/SC)",
    "python-yubikey-manager": "YubiKey configuration tool (Python)",
    "python-debugpy": "Python debugger adapter (DAP protocol)",
    "ssh-to-age": "Convert SSH keys to age keys",
    "pup": "HTML parser CLI (jq for HTML, Go)",
    "witr": "WireGuard interactive TUI configurator",
    "math": "Mathematics / calculator (often calc or qalc)",
    "virtio-win": "VirtIO Windows drivers for QEMU guests",
    "limine": "Limine bootloader",
    "vicinae": "Qt6 launcher/dashboard (custom fork)",
    "vicinae-bin": "Qt6 launcher/dashboard (prebuilt binary)",
    "xray": "Proxy/VPN tool (Xray-core, v2fly)",
    "v2raya": "V2Ray web GUI client (alternative to V2Ray)",
    "v2rayn": "V2Ray Windows GUI client",
    "sing-box": "Universal proxy platform (Go, SagerNet)",
    "zapret2": "DPI bypass tool (discord, youtube, tiktok, etc)",
    "kanata": "Keyboard remapper daemon (Rust)",
    "proxypilot": "Proxy management/provisioning tool (Go)",
    "zen-browser-bin": "Zen Browser (Firefox fork, privacy-focused)",
    "zen-browser": "Zen Browser (Firefox fork, privacy-focused)",
    "floorp": "Firefox-based browser (Japanese, extra features)",
    "albumdetails": "Music album metadata viewer CLI",
    "ananicy-cpp": "Auto-Nice daemon (C++, process priority management)",
    "bazecor": "Dygma Raise keyboard configurator (GUI)",
    "clipcat": "Clipboard manager for Wayland (Rust)",
    "ddccontrol": "DDC/CI monitor control (brightness, input, etc.)",
    "epr": "Terminal EPUB reader (Rust)",
    "flclashx": "FlClashX proxy client (Flutter GUI)",
    "font-iosevkaterm-nerd-fonts": "IosevkaTerm Nerd Font patched",
    "font-iosevka-nerd-fonts": "Iosevka Nerd Font patched",
    "font-material-design-icons": "Material Design Icons font",
    "ght": "GitHub CLI extensions manager (Rust)",
    "goverlay": "GUI overlay manager for MangoHud/Goverlay",
    "hermes-agent": "Hermes AI agent (Nous Research assistant)",
    "hishtory": "Sync shell history across machines (end-to-end encrypted)",
    "instagram-cli": "Instagram CLI viewer/downloader (Rust)",
    "jetm-kernel-settings": "Custom kernel settings/tuning (JetM)",
    "libjodycode": "Library for file operations (used by jdupes, etc.)",
    "massren": "Mass file renamer (Rust)",
    "neo-matrix": "Matrix digital rain screensaver (C, neofetch-like)",
    "ollama": "Local LLM runner (llama.cpp wrapper, Go)",
    "opensoundmeter": "Audio level/spectrum analyzer (like SPL meter)",
    "oports": "Port scanner/analyzer CLI tool",
    "optiscaler": "FSR/DLSS upscaler switcher (Windows compatibility)",
    "otter-launcher": "Application launcher (Qt, Otter Browser companion)",
    "par": "Paragraph reformatter (text formatting CLI)",
    "powerlevel10k": "Zsh theme with performance (custom theme)",
    "proteinview": "Protein structure viewer (molecular graphics)",
    "proton-ge-custom": "Proton GE (community Wine fork for Steam)",
    "protontricks": "Winetricks wrapper for Proton/Steam Play",
    "python-uv-dynamic-versioning": "Python version management via uv (dynamic)",
    "pzip": "Parallel compression tool (pigz-like, custom)",
    "regex-tui": "Regex tester/editor (TUI, Rust)",
    "richcolors": "Terminal true-color generator (256-colors)",
    "roomeqwizard": "Room EQ Wizard (audio measurement/equalization)",
    "rsmetrx": "Rust SMetrics (network metrics collection)",
    "rustmission": "Rust BitTorrent client (TUI)",
    "sidecar": "Sidecar proxy (network tool, Tailscale sidecar)",
    "slsa-verifier": "SLSA provenance verifier (supply-chain security)",
    "songfetch": "Song info fetcher (MPD/Last.fm, Rust)",
    "spdlog": "Fast C++ logging library",
    "tailray": "Tailscale IP/host manager (TUI, Rust)",
    "tanin": "TUI audio visualizer (Rust)",
    "taoup": "Terminal-based ASCII/Unicode art generator",
    "tmmpr": "Twitch/Trovo/YouTube chat reader (TUI)",
    "ytsurf": "YouTube CLI player/search (Rust)",
    "pup": "HTML parser CLI (jq for HTML, Go)",
    "witr": "WireGuard interactive TUI configurator",
    "xdg-ninja": "Fix XDG base directory compliance for apps",
    "iosevka-neg-fonts": "Custom Iosevka font variant (Nergo)",
    "wiremix": "MPD visualizer with PipeWire support",
    "proxypilot": "ProxyPilot LLM API proxy (Go)",
    "game-devices-udev": "Udev rules for gaming devices (controllers, wheels)",
    "opencode": "OpenCode AI coding assistant (CLI)",
    "hyprscratch": "Hyprland scratchpad manager (Rust)",
    "nautilus": "GNOME file manager",
    "simple-scan": "Document scanner GUI",
    "sushi": "GNOME file previewer (quick preview)",
    "loupe": "GNOME image viewer",
    "gnome-calculator": "GNOME calculator app",
    "gnome-calendar": "GNOME calendar app",
    "gnome-logs": "GNOME system log viewer",
    "gnome-maps": "GNOME maps app",
    "gnome-music": "GNOME music player",
    "gnome-software": "GNOME software center",
    "gnome-system-monitor": "GNOME task manager",
    "gnome-text-editor": "GNOME text editor",
    "gnome-tweaks": "GNOME advanced settings",
    "gnome-weather": "GNOME weather app",
    "gnome-backgrounds": "GNOME wallpapers",
    "gnome-keyring": "GNOME Keyring (secrets storage)",
    "gnome-session": "GNOME desktop session",
    "gvfs": "GNOME virtual filesystem",
    "swayosd": "OSD overlay for Wayland (volume/brightness)",
    "matugen": "Material You color generator",
    "rmpc": "Terminal MPD client (Rust/NCurses)",
    "television": "Terminal television (TUI tool?)",
    "wlogout": "Wayland logout/reboot/shutdown screen",
    "swaylock": "Wayland screen locker",
    "kmon": "Kernel module manager TUI",
}

# ── Configs that store package names as "quoted strings" (Guix)
GUIX_STRING_PKGS = True

def annotate_nixos():
    """Annotate NixOS packages.nix"""
    path = REPO / "vms/nixos/modules/packages.nix"
    with open(path) as f:
        content = f.read()
    
    lines = content.split("\n")
    new_lines = []
    changed = 0
    
    for line in lines:
        m = re.match(r'^(\s*)([\w.\-]+)\s*(#.*)?$', line)
        if m and not line.strip().startswith("#") and not line.strip().startswith("}") and not line.strip().startswith("]"):
            indent = m.group(1); pkg = m.group(2).strip()
            existing = (m.group(3) or "").strip("# ").strip()
            if len(existing) > 5:
                new_lines.append(line); continue
            if "(" in pkg:
                new_lines.append(line); continue
            desc = DESC.get(pkg)
            if desc:
                new_lines.append(f"{indent}{pkg:30} # {desc}"); changed += 1
            else:
                new_lines.append(line)
        else:
            new_lines.append(line)
    
    with open(path, "w") as f:
        f.write("\n".join(new_lines))
    print(f"NixOS: annotated {changed} packages")

def annotate_salt():
    """Annotate Salt packages.yaml"""
    path = REPO / "states/data/packages.yaml"
    with open(path) as f:
        content = f.read()
    
    lines = content.split("\n")
    new_lines = []; changed = 0
    
    for line in lines:
        m = re.match(r'^(\s*-\s*)([\w.\-]+)(\s*#.*)?$', line)
        if m:
            indent = m.group(1); pkg = m.group(2).strip()
            existing = (m.group(3) or "").strip("# ").strip()
            if len(existing) > 5:
                new_lines.append(line); continue
            desc = DESC.get(pkg)
            if desc:
                new_lines.append(f"{indent}{pkg:30} # {desc}"); changed += 1
            else:
                new_lines.append(line)
        else:
            new_lines.append(line)
    
    with open(path, "w") as f:
        f.write("\n".join(new_lines))
    print(f"Salt: annotated {changed} packages")

def annotate_guix():
    print("Guix: skipped (no guix/ directory)")

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--nixos", action="store_true")
    parser.add_argument("--salt", action="store_true")
    parser.add_argument("--guix", action="store_true")
    args = parser.parse_args()
    
    do_all = not (args.nixos or args.salt or args.guix)
    
    if do_all or args.nixos:
        annotate_nixos()
    if do_all or args.salt:
        annotate_salt()
    if do_all or args.guix:
        annotate_guix()
    
    print("Done! Run 'just validate' or 'nix flake check' to verify")

if __name__ == "__main__":
    main()
