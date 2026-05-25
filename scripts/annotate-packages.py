#!/usr/bin/env python3
"""
Annotate package lists with descriptions in Salt (YAML), NixOS (Nix), and Guix (Scheme).

Reads package names from each config file and adds inline # comments with descriptions.
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

DESC = {
    # ── core utils ──
    "eza": "Modern ls replacement (Rust)",
    "fd": "Fast file search replacement (Rust)",
    "bat": "cat replacement with syntax highlighting (Rust)",
    "ripgrep": "Ultra-fast grep replacement (Rust)",
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
    "duf": "Disk usage/free utility (Go)",
    "doggo": "Modern DNS client (Go)",
    "xh": "HTTP client like httpie (Rust)",
    "httpie": "User-friendly HTTP client (Python)",
    "curlie": "curl wrapper with httpie-style output (Go)",
    "bandwhich": "Terminal bandwidth utilization tool (Rust)",
    "btop": "Resource monitor (C++)",
    "fastfetch": "Neofetch replacement (C)",
    "helix": "Modal text editor (Rust)",
    "neovim": "Modern Vim fork (Lua-first)",
    "nvim": "Modern Vim fork (Neovim binary)",
    "lazygit": "Terminal Git UI (Go)",
    "ouch": "Compression/decompression CLI (Rust)",
    "onefetch": "Git repository summary tool (Rust)",
    "pastel": "Color manipulation tool (Rust)",
    "cargo": "Rust package manager includes rustc",
    "go": "Go programming language compiler + tools",
    "docker": "Container runtime CLI + daemon",
    "zellij": "Terminal multiplexer (Rust)",
    "taplo": "TOML formatter and linter (Rust)",
    "watchexec": "File watcher that runs commands (Rust)",
    "jq": "JSON query processor (C)",
    "jc": "Convert CLI tool output to JSON (Python)",
    "yq-go": "YAML/JSON/XML processor (Go)",
    "miller": "CSV/JSON/TSV data processor mlr (Go)",
    "scc": "Code line counter like cloc (Go)",
    "shfmt": "Shell script formatter (Go)",
    "shellcheck": "Shell script static analyzer (Haskell)",
    "pre-commit": "Git pre-commit hook framework (Python)",
    "ruff": "Python linter and formatter (Rust)",
    "handlr-regex": "Default application handler (Rust)",
    "uwsm": "Universal Wayland Session Manager",
    "cliphist": "Wayland clipboard manager (Go)",
    "wl-clipboard": "Wayland clipboard tools wl-copy wl-paste",
    "wev": "Wayland event viewer",
    "wtype": "Wayland keystroke injector",
    "grim": "Wayland screenshot tool",
    "slurp": "Wayland region selector",
    "swayimg": "Wayland image viewer",
    "satty": "Screenshot annotation tool (Rust)",
    "wf-recorder": "Wayland screen recorder",
    "wlogout": "Wayland logout screen",
    "wofi": "Wayland launcher menu like rofi",
    "rofi": "Application launcher for X11 and Wayland",
    "dunst": "Notification daemon",
    "waypipe": "Wayland remote display like SSH -X",
    "wayvnc": "VNC server for Wayland compositors",
    "wlr-randr": "Wayland output management CLI",
    "hypridle": "Hyprland idle daemon",
    "hyprlock": "Hyprland screen locker",
    "hyprpicker": "Hyprland color picker",
    "hyprland": "Dynamic tiling Wayland compositor",
    "niri": "Scrolling-tiling Wayland compositor",
    "ghostty": "GPU-accelerated terminal emulator",
    "kitty": "GPU-accelerated terminal emulator",
    "alacritty": "GPU-accelerated terminal emulator (Rust)",
    "wezterm": "GPU-accelerated terminal emulator",
    "foot": "Wayland-native terminal emulator",
    "konsole": "KDE terminal emulator",
    "mpv": "Media player (C)",
    "ffmpeg": "Multimedia converter and processor",
    "ffmpegthumbnailer": "Video thumbnail generator",
    "yt-dlp": "YouTube/video downloader",
    "imagemagick": "Image manipulation suite",
    "rclone": "Cloud storage sync (Go)",
    "borgbackup": "Deduplicating backup tool (Python/C)",
    "borg": "Deduplicating backup tool (Python/C)",
    "restic": "Fast backup program (Go)",
    "podman": "Daemonless container engine (Go)",
    "skopeo": "Container image inspection tool (Go)",
    "nerdctl": "Docker-compatible CLI for containerd (Go)",
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
    "s-tui": "Terminal CPU stress test and monitor (Python)",
    "bottom": "Graphical system monitor btm (Rust)",
    "gping": "Ping with graph display (Rust)",
    "procs": "ps replacement (Rust)",
    "mpc": "MPD client (Music Player Daemon)",
    "mpd": "Music Player Daemon (server)",
    "mpdas": "Last.fm scrobbler for MPD",
    "mpdris2": "MPRIS bridge for MPD",
    "wiremix": "MPD visualizer with PipeWire support",
    "patchelf": "ELF binary patching tool",
    "strace": "System call tracer",
    "valgrind": "Memory debugger and profiler",
    "gdb": "GNU debugger",
    "clang": "C/C++/ObjC compiler (LLVM)",
    "gcc": "GNU C/C++ compiler",
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
    "m4": "GNU M4 macro processor",
    "openssh": "SSH client and server",
    "openssl": "SSL/TLS cryptography library plus CLI",
    "curl": "HTTP client and data transfer tool",
    "wget": "HTTP download tool",
    "nmap": "Network scanner and discovery tool",
    "tcpdump": "Packet capture and analysis CLI",
    "socat": "Multipurpose socket relay tool",
    "iperf3": "Network bandwidth measurement tool",
    "mtr": "Network diagnostic (traceroute + ping)",
    "whois": "Domain and WHOIS lookup client",
    "networkmanagerapplet": "NetworkManager tray applet",
    "firewalld": "Firewall management daemon (firewall-cmd)",
    "bluez": "Bluetooth protocol stack and tools",
    "bluez-utils": "Bluetooth protocol stack and tools",
    "upower": "Power management abstraction layer",
    "powertop": "Power consumption diagnosis tool",
    "inxi": "System information script",
    "fio": "Flexible I/O tester/benchmark",
    "stress-ng": "CPU/memory/IO stress testing tool",
    "hyperfine": "Command-line benchmarking tool (Rust)",
    "sysstat": "System performance monitoring (sar, iostat)",
    "vnstat": "Network traffic monitor",
    "vnstatd": "Network traffic monitor daemon",
    "htop": "Interactive process viewer",
    "iftop": "Network bandwidth by connection (top-like)",
    "nethogs": "Network bandwidth by process (top-like)",
    "lolcat": "Rainbow text colorizer",
    "pciutils": "PCI bus utilities (lspci)",
    "usbutils": "USB device utilities (lsusb)",
    "smartmontools": "S.M.A.R.T. disk monitoring tools",
    "nodejs": "JavaScript runtime (Node.js)",
    "ruby": "Ruby programming language",
    "python3": "Python 3 programming language",
    "uv": "Fast Python package manager (Rust)",
    "vale": "Prose linter (documentation style)",
    "lua-language-server": "Lua language server (LSP)",
    "lua5_3": "Lua 5.3 programming language",
    "lua53": "Lua 5.3 programming language",
    "fennel": "Lisp that compiles to Lua (luaPackages)",
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
    "choose": "cut and awk replacement (Rust)",
    "grex": "Regex generator from examples (Rust)",
    "htmlq": "HTML query tool like jq for HTML (Rust)",
    "procs": "ps replacement (Rust)",
    "dog": "DNS lookup tool (Rust)",
    "curlie": "curl with httpie-style output (Go)",
    "bandwhich": "Bandwidth utilization TUI (Rust)",
    "httpie": "HTTP client with user-friendly output (Python)",
    "websocat": "WebSocket client and server (Rust)",
    "nmh": "Mail handling system (classic nmh)",
    "notmuch": "Email system (fast mail indexer)",
    "himalaya": "Email CLI client (Rust)",
    "mbsync": "Mailbox synchronizer (IMAP/Maildir)",
    "msmtp": "SMTP mail client",
    "vdirsyncer": "CalDAV/CardDAV sync tool",
    "khal": "CalDAV calendar CLI client (Python)",
    "tessen": "2FA/HOTP/TOTP CLI (Python)",
    "imapnotify": "IMAP idle push notification",
    "neomutt": "Mutt email client fork with modern features",
    "mutt": "Email client (text-based)",
    "bucklespring": "Keyboard sound effects (IBM Model M)",
    "cava": "Console audio visualizer",
    "cdparanoia": "CD audio ripping tool",
    "chafa": "Terminal image viewer/probe",
    "chromaprint": "Acoustic fingerprinting library + CLI",
    "aria2": "Download utility supporting multiple protocols",
    "blender": "3D creation suite",
    "carla": "Audio plugin host (LV2/VST2/DSSI)",
    "cowsay": "ASCII art cow speech bubble",
    "chromium": "Web browser (open-source Chrome)",
    "epiphany": "GNOME web browser (WebKit)",
    "firefox": "Web browser",
    "zen-browser": "Privacy-focused Firefox fork",
    "floorp": "Firefox fork with extra features",
    "gimp": "GNU Image Manipulation Program",
    "lutris": "Game launcher (Wine/libretro/native)",
    "wine": "Windows compatibility layer",
    "gamescope": "Micro-compositor for gaming (Valve)",
    "gamemode": "Game performance optimization daemon",
    "nethack": "Classic roguelike dungeon crawler",
    "steam": "Steam gaming platform (via nonguix/unfree)",
    "amdgpu-vulkan-switcher": "AMD GPU Vulkan driver switcher",
    "amd-ucode": "AMD CPU microcode updates",
    "vitunes": "Music player with vi-style keybindings",
    "ytfzf": "YouTube search and player from terminal",
    "ytsurf": "CLI YouTube player/downloader",
}

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
            indent = m.group(1)
            pkg = m.group(2).strip()
            existing = (m.group(3) or "").strip("# ").strip()
            
            if len(existing) > 5:
                new_lines.append(line)
                continue
            if "(" in pkg:
                new_lines.append(line)
                continue
            
            desc = DESC.get(pkg)
            if desc:
                new_lines.append(f"{indent}{pkg:30} # {desc}")
                changed += 1
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
    new_lines = []
    changed = 0
    current_category = ""
    
    for line in lines:
        m = re.match(r'^(\s*-\s*)([\w.\-]+)(\s*#.*)?$', line)
        if m:
            indent = m.group(1)
            pkg = m.group(2).strip()
            existing = (m.group(3) or "").strip("# ").strip()
            
            if len(existing) > 5:
                new_lines.append(line)
                continue
            
            desc = DESC.get(pkg)
            if desc:
                new_lines.append(f"{indent}{pkg:30} # {desc}")
                changed += 1
            else:
                new_lines.append(line)
        else:
            new_lines.append(line)
    
    with open(path, "w") as f:
        f.write("\n".join(new_lines))
    print(f"Salt: annotated {changed} packages")

def annotate_guix():
    """Annotate Guix config — packages in specifications and plain lists."""
    path = REPO / "guix/system-config.scm"
    with open(path) as f:
        content = f.read()
    
    lines = content.split("\n")
    new_lines = []
    changed = 0
    
    for line in lines:
        # Match Guix package references: symbol, string, or (list ...) member
        # Plain package names in lists:   zsh git neovim tmux bat
        # String packages:                \"albumdetails\" \"ananicy-cpp\"
        m = re.match(r'^(\s*)([\w.\-]+)\s*(;.*)?$', line)
        m_str = re.match(r'^(\s*)"([\w.\-]+)"\s*(;.*)?$', line)
        
        pkg = None
        indent = None
        existing = None
        
        if m and not line.strip().startswith(";"):
            pkg = m.group(2).strip()
            indent = m.group(1)
            existing = (m.group(3) or "").lstrip("; ").strip()
            
            # Skip Scheme keywords and module names
            if pkg in ["specifications->packages", "specifications", "packages", "system",
                       "operating", "services", "users", "cons", "list", "append",
                       "file", "plain", "local", "string"]:
                new_lines.append(line)
                continue
            if pkg.startswith("(") or pkg.startswith("#") or pkg == "|":
                new_lines.append(line)
                continue
        
        # Handle "quoted" package names in lists
        if m_str:
            pkg = m_str.group(2).strip()
            indent = m_str.group(1)
            existing = (m_str.group(3) or "").lstrip("; ").strip()
        
        if pkg and len(existing) < 5:
            desc = DESC.get(pkg)
            if desc:
                if m_str:
                    new_lines.append(f'{indent}"{pkg}"{" " * (28 - len(pkg))} ; {desc}')
                else:
                    new_lines.append(f"{indent}{pkg:30} ; {desc}")
                changed += 1
            else:
                new_lines.append(line)
        elif pkg:
            new_lines.append(line)
        else:
            new_lines.append(line)
    
    with open(path, "w") as f:
        f.write("\n".join(new_lines))
    print(f"Guix: annotated {changed} packages")

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
