#!/usr/bin/env python3
"""Annotate NixOS packages.nix with inline descriptions."""

import re
from pathlib import Path
import subprocess, sys

REPO = Path(__file__).resolve().parent.parent
NIXOS_PKGS = REPO / "vms/nixos/modules/packages.nix"

DESC = {
    "eza": "Modern ls replacement",
    "fd": "Fast find replacement",
    "bat": "cat replacement with syntax highlighting",
    "ripgrep": "Recursive grep replacement",
    "delta": "Git diff viewer with syntax highlighting",
    "difftastic": "Structural diff tool",
    "jujutsu": "Git-compatible VCS (jj), simpler than git",
    "zoxide": "Smarter cd command (frecency-based)",
    "fzf": "Fuzzy finder for the terminal",
    "tealdeer": "Fast tldr client (man page examples)",
    "just": "Command runner (like make, simpler)",
    "yazi": "Terminal file manager",
    "chezmoi": "Dotfile manager (declarative)",
    "gopass": "Password manager with git/age backend",
    "age": "Simple, modern file encryption",
    "broot": "Tree-based file explorer",
    "duf": "Disk usage/free utility",
    "doggo": "Modern DNS client",
    "xh": "HTTP client like httpie",
    "curlie": "curl wrapper (httpie-style output)",
    "bandwhich": "Terminal bandwidth utilization tool",
    "btop": "Resource monitor",
    "fastfetch": "Neofetch replacement",
    "helix": "Modal text editor",
    "neovim": "Modern Vim fork",
    "lazygit": "Terminal Git UI",
    "ouch": "Compression/decompression CLI",
    "onefetch": "Git repository summary tool",
    "pastel": "Color manipulation tool",
    "cargo": "Rust package manager (includes rustc)",
    "go": "Go programming language (golang compiler + tools)",
    "docker": "Container runtime (CLI + daemon)",
    "zellij": "Terminal multiplexer",
    "taplo": "TOML formatter/linter",
    "watchexec": "File watcher that runs commands",
    "jq": "JSON query processor",
    "jc": "JSON convert output of CLI tools",
    "yq-go": "YAML/JSON/XML processor",
    "miller": "CSV/JSON/TSV data processor (mlr)",
    "scc": "Code line counter (like cloc)",
    "shfmt": "Shell script formatter",
    "shellcheck": "Shell script static analyzer",
    "pre-commit": "Git pre-commit hook framework",
    "ruff": "Python linter + formatter",
    "handlr-regex": "Default application handler",
    "uwsm": "Universal Wayland Session Manager",
    "cliphist": "Wayland clipboard manager",
    "wl-clipboard": "Wayland clipboard tools (wl-copy, wl-paste)",
    "wev": "Wayland event viewer",
    "wtype": "Wayland keystroke injector",
    "grim": "Wayland screenshot tool",
    "slurp": "Wayland region selector",
    "swayimg": "Wayland image viewer",
    "satty": "Screenshot annotation tool",
    "wf-recorder": "Wayland screen recorder",
    "wlogout": "Wayland logout screen",
    "wofi": "Wayland launcher menu (like rofi)",
    "rofi": "Application launcher (X11/Wayland)",
    "dunst": "Notification daemon",
    "waypipe": "Wayland remote display (like SSH -X)",
    "wayvnc": "VNC server for Wayland",
    "wlr-randr": "Wayland output management CLI",
    "hypridle": "Hyprland idle daemon",
    "hyprlock": "Hyprland screen locker",
    "hyprpicker": "Hyprland color picker",
    "hyprland": "Dynamic tiling Wayland compositor",
    "niri": "Scrolling-tiling Wayland compositor",
    "ghostty": "GPU-accelerated terminal emulator",
    "kitty": "GPU-accelerated terminal emulator",
    "alacritty": "GPU-accelerated terminal emulator",
    "wezterm": "GPU-accelerated terminal emulator",
    "mpv": "Media player",
    "ffmpeg": "Multimedia converter/processor",
    "yt-dlp": "YouTube/video downloader",
    "imagemagick": "Image manipulation suite",
    "rclone": "Cloud storage sync",
    "borgbackup": "Deduplicating backup tool",
    "restic": "Fast backup program",
    "podman": "Daemonless container engine",
    "skopeo": "Container image inspection tool",
    "nerdctl": "Docker-compatible CLI for containerd",
    "slirp4netns": "User-mode networking for containers",
    "tailscale": "Mesh VPN",
    "unbound": "Recursive DNS resolver",
    "avahi": "mDNS/DNS-SD (zeroconf) daemon",
    "nssmdns": "mDNS hostname resolution via nsswitch",
    "iwd": "Wi-Fi daemon (iNet Wireless Daemon)",
    "dnsmasq": "Lightweight DNS/DHCP/TFTP server",
    "kmon": "Kernel module manager TUI",
    "lnav": "Log file navigator",
    "ctop": "Container metrics TUI",
    "dive": "Docker image layer analysis TUI",
    "s-tui": "Terminal CPU stress + monitor",
    "bottom": "Graphical system monitor (btm)",
    "gping": "Ping with graph display",
    "procs": "ps replacement",
    "mpc": "MPD client (Music Player Daemon)",
    "mpd": "Music Player Daemon (server)",
    "mpdas": "Last.fm scrobbler for MPD",
    "mpdris2": "MPRIS bridge for MPD",
    "wiremix": "MPD visualizer with PipeWire",
    "patchelf": "ELF binary patching tool",
    "strace": "System call tracer",
    "valgrind": "Memory debugger/profiler",
    "gdb": "GNU debugger",
    "clang": "C/C++/ObjC compiler (LLVM)",
    "gcc": "GNU C/C++ compiler",
    "cmake": "Cross-platform build system",
    "meson": "Fast build system (Python/Ninja)",
    "ninja": "Small build system (used by Meson)",
    "gnumake": "GNU Make build system",
    "autoconf": "GNU Autoconf — portable configure scripts",
    "automake": "GNU Automake — Makefile generator",
    "libtool": "GNU Libtool — library support tool",
    "pkg-config": "Library dependency resolver",
    "bison": "Parser generator (yacc replacement)",
    "flex": "Lexical analyzer generator (lex replacement)",
    "openssh": "SSH client and server",
    "curl": "HTTP client and data transfer tool",
    "wget": "HTTP download tool",
    "httpie": "User-friendly HTTP client",
    "nmap": "Network scanner and discovery tool",
    "tcpdump": "Packet capture/analysis CLI",
    "socat": "Multipurpose socket relay tool",
    "iperf3": "Network bandwidth measurement tool",
    "mtr": "Network diagnostic (traceroute + ping)",
    "whois": "Domain/WHOIS lookup client",
    "networkmanager": "Network management daemon",
    "networkmanagerapplet": "NetworkManager tray applet",
    "firewalld": "Firewall management daemon",
    "bluez": "Bluetooth protocol stack + tools",
    "upower": "Power management abstraction layer",
    "powertop": "Power consumption diagnosis tool",
    "inxi": "System information script",
    "fio": "Flexible I/O tester/benchmark",
    "stress-ng": "CPU/memory/IO stress testing tool",
    "hyperfine": "Command-line benchmarking tool",
    "sysstat": "System performance monitoring (sar, iostat)",
    "vnstat": "Network traffic monitor",
    "htop": "Interactive process viewer",
    "lolcat": "Rainbow text colorizer",
    "pciutils": "PCI bus utilities (lspci)",
    "usbutils": "USB device utilities (lsusb)",
    "smartmontools": "S.M.A.R.T. disk monitoring tools",
    "nodejs": "JavaScript runtime (Node.js)",
    "ruby": "Ruby programming language",
    "python3": "Python 3 programming language",
    "uv": "Fast Python package manager (uv, Rust)",
    "vale": "Prose linter (documentation style checker)",
    "lua-language-server": "Lua language server (LSP)",
    "lua5_3": "Lua 5.3 programming language",
    "fennel": "Lisp that compiles to Lua (luaPackages)",
    "pipx": "Install Python tools in isolated environments",
    "git": "Distributed version control system",
    "delta": "Git diff viewer with syntax highlighting",
    "tig": "Text-mode Git repository browser",
    "git-crypt": "Transparent git file encryption",
    "git-lfs": "Git Large File Storage extension",
    "git-filter-repo": "Git repository rewriting tool",
    "gh": "GitHub CLI (pull requests, issues, etc)",
    "gitleaks": "Git secret scanner (pre-commit hooks)",
    "gist": "GitHub Gist CLI tool",
    "subversion": "Apache Subversion (SVN) VCS",
    "act": "Run GitHub Actions locally",
    "nodejs": "JavaScript runtime (Node.js)",
    "rustc": "Rust compiler",
    "go": "Go programming language",
    "uv": "Python package manager (Rust, pip replacement)",
    "vale": "Prose linter (documentation style)",
    "yamllint": "YAML file linter",
    "taplo": "TOML formatter/linter",
    "tree-sitter": "Parser generator for syntax highlighting",
    "ruff": "Python linter/formatter (Rust)",
    "pre-commit": "Git pre-commit hook framework",
    "shfmt": "Shell script formatter",
    "shellcheck": "Shell script static analyzer",
    "ripgrep": "Ultra-fast grep replacement",
    "fd": "Fast file search replacement",
    "eza": "Modern ls replacement",
    "bat": "cat replacement with syntax highlighting",
    "procs": "ps replacement",
    "duf": "Disk usage/free utility",
    "doggo": "Modern DNS client",
    "xh": "HTTP client like httpie",
    "curlie": "curl wrapper (httpie output)",
    "choose": "cut and awk replacement",
    "pastel": "Color manipulation tool",
    "bandwhich": "Bandwidth utilization TUI",
    "grex": "Regex generator from examples",
    "htmlq": "HTML query tool (like jq for HTML)",
}

def normalize_pkg_name(pkg):
    """Normalize Nix package expression to lookup key."""
    pkg = pkg.strip().rstrip(",")
    # Handle attrset paths like "gst_all_1.gst-plugins-bad"
    return pkg.split(".")[-1]

def run():
    with open(NIXOS_PKGS) as f:
        lines = f.readlines()
    
    new_lines = []
    annotated = 0
    already = 0
    
    for line in lines:
        stripped = line.strip()
        match = re.match(r'^(\s*)([\w.\-]+(?:\(.*?\))?)\s*(#.*)?$', line)
        if match and not stripped.startswith("#") and not stripped.startswith("}"):
            indent = match.group(1)
            pkg_raw = match.group(2).strip()
            existing_comment = match.group(3) or ""
            
            # Skip attrset patterns (python3.withPackages, etc)
            if "(" in pkg_raw or ")" in pkg_raw:
                new_lines.append(line)
                continue
            
            # Skip if already has meaningful comment
            comment_text = existing_comment.lstrip("# ").strip()
            if comment_text and len(comment_text) > 5:
                already += 1
                new_lines.append(line)
                continue
            
            pkg_key = normalize_pkg_name(pkg_raw)
            desc = DESC.get(pkg_key)
            if desc and not existing_comment.strip():
                new_lines.append(f"{indent}{pkg_raw:30} # {desc}\n")
                annotated += 1
            else:
                new_lines.append(line)
        else:
            new_lines.append(line)
    
    with open(NIXOS_PKGS, "w") as f:
        f.writelines(new_lines)
    
    print(f"NixOS: annotated {annotated} packages, {already} already had comments")

if __name__ == "__main__":
    run()
