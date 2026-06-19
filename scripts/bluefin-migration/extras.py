#!/usr/bin/env python3
"""Extend the Bluefin Containerfile with:
  - 8 Fedora RPMs that were missed in the initial mapping
  - Google Chrome RPM repo
  - COPR repos for AUR packages available there
  - npm packages
  - Extended cargo/pip/go sections
  - Binary downloads from GitHub releases
  - Source builds for C/C++/Lua/shell packages

Reads missing.txt and stone recipes to generate additions.
"""

import yaml
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
STONE_ROOT = REPO_ROOT / "build" / "stone-recipes"


# ── 1. Fedora RPMs that were missed ─────────────────────────────────
# These ARE in Fedora but our generator didn't map them
MISSED_RPMS = [
    "dcfldd",
    "nethack",
    "rmlint",
    "swappy",
    "ttfautohint",
    "wlogout",
]

# ── 2. Google Chrome ────────────────────────────────────────────────
GOOGLE_CHROME = True  # Add google-chrome-stable from Google's repo

# ── 3. COPR repos ───────────────────────────────────────────────────
COPR_REPOS = {
    "v2raya": "nicknamenull/v2raya",
    "amneziawg-dkms": "amneziavpn/amneziawg",
    "amneziawg-tools": "amneziavpn/amneziawg",
    "sing-box": "duament/sing-box",
    "cosmic-greeter": "ryanabx/cosmic-epoch",
    "swayosd": "erikreider/SwayNotificationCenter",
    "satty": "errornointernet/packages",
}

# ── 4. npm packages ─────────────────────────────────────────────────
NPM_PKGS = [
    "@anthropic-ai/claude-code",
]

# ── 5. Extended cargo ──────────────────────────────────────────────
EXTRA_CARGO = [
    "amdgpu_top",
    "hyprscratch",
    "lutgen",
    "regex-tui",
    "rmpc",
    "rustmission",
    "systemd-manager-tui",
    "youtube-tui",
    "otter-launcher",
    "wlr-which-key",
    "oyo",
    "tmmpr",
]

# ── 6. Extended pip ─────────────────────────────────────────────────
EXTRA_PIP = [
    "cmake-language-server",
    "dool",
    "epr-reader",
    "mpDris2",
    "patool",
    "protonvpn-cli",
    "raysession",
]

# ── 7. Extended go ─────────────────────────────────────────────────
EXTRA_GO = {
    "ssh-to-age": "github.com/Mic92/ssh-to-age/cmd/ssh-to-age@latest",
    "scc": "github.com/boyter/scc/v3@latest",
    "massren": "github.com/laurent22/massren@latest",
    "unflac": "github.com/derat/unflac@latest",
    "ytsurf": "github.com/irevenko/ytsurf@latest",
}

# ── 8. Binary downloads ─────────────────────────────────────────────
# (folder_name => github_repo, binary_name, asset_pattern)
BINARIES = {
    "aliae": ("JanDeDobbeleer/aliae", "aliae", "aliae_.*_linux_amd64.tar.gz"),
    "carapace": ("carapace-sh/carapace-bin", "carapace", "carapace_.*_linux_amd64.tar.gz"),
    "freeze": ("charmbracelet/freeze", "freeze", "freeze_.*_Linux_x86_64.tar.gz"),
    "hishtory": ("ddworken/hishtory", "hishtory", "hishtory-linux-amd64"),
    "pup": ("ericchiang/pup", "pup", "pup_.*_linux_amd64.zip"),
    "sing-box": ("SagerNet/sing-box", "sing-box", "sing-box-.*-linux-amd64.tar.gz"),
    "strace-tui": ("nickelc/strace-tui", "strace-tui", ".*linux.*"),
    "v2raya": ("v2rayA/v2rayA", "v2raya", "v2raya_.*_linux_x64.tar.gz"),
    "watchtower": ("containrrr/watchtower", "watchtower", "watchtower_.*_linux_amd64.tar.gz"),
    "gowall": ("Achno/gowall", "gowall", "gowall_.*_linux_amd64.tar.gz"),
    # Additional binaries from research
    "eilmeldung": ("qcasey/eilmeldung", "eilmeldung", "eilmeldung_.*_linux_amd64.tar.gz"),
    "reddix": ("crosstype/reddix", "reddix", "reddix_.*_linux_amd64.tar.gz"),
    "simutil": ("google/simutil", "simutil", "simutil_.*_linux_amd64.tar.gz"),
    "witr": ("siddharthroy12/witr", "witr", "witr_.*_linux_amd64.tar.gz"),
    "v2rayn": ("2dust/v2rayN", "v2rayN", "v2rayN_.*_linux_amd64.tar.gz"),
    "flclash": ("chen08209/FlClash", "FlClash", "FlClash_.*_linux_amd64.tar.gz"),
}

# ── 9. Source builds ────────────────────────────────────────────────
# (name, clone_url, build_cmds, deps)
SOURCE_BUILDS = {
    "bucklespring": {
        "repo": "https://github.com/zevv/bucklespring.git",
        "deps": "gcc make libpulse-devel libxtst-devel",
        "build": "make && install -m755 buckle /usr/local/bin/",
    },
    "dualsensectl": {
        "repo": "https://github.com/nowrep/dualsensectl.git",
        "deps": "gcc meson ninja-build pkgconfig(sdl2) pkgconfig(libudev) pkgconfig(dbus-1) pkgconfig(hidapi-hidraw)",
        "build": "meson setup builddir && ninja -C builddir && ninja -C builddir install",
    },
    "mpdas": {
        "repo": "https://github.com/hrkfdn/mpdas.git",
        "deps": "gcc gcc-c++ make libcurl-devel libmpdclient-devel",
        "build": "make && install -m755 mpdas /usr/local/bin/",
    },
    "neo-matrix": {
        "repo": "https://github.com/st3w/neo.git",
        "deps": "gcc make autoconf automake ncurses-devel",
        "build": "autoreconf -fi && ./configure && make && make install",
    },
    "zapret2": {
        "repo": "https://github.com/bol-van/zapret.git",
        "deps": "gcc make",
        "build": "cd ip2net && make && install -m755 ip2net /usr/local/bin/",
    },
    "pipemixer-git": {
        "repo": "https://github.com/nickelc/pipemixer.git",
        "deps": "gcc meson ninja-build pipewire-devel ncurses-devel",
        "build": "meson setup builddir && ninja -C builddir && ninja -C builddir install",
    },
    "rofi-file-browser-extended-git": {
        "repo": "https://github.com/marvinkreis/rofi-file-browser-extended.git",
        "deps": "gcc cmake make rofi-devel",
        "build": "mkdir build && cd build && cmake .. && make && make install",
    },
    "tessen": {
        "repo": "https://github.com/ayushnix/tessen.git",
        "deps": "",
        "build": "PREFIX=/usr/local make install",
    },
    "xdg-ninja": {
        "repo": "https://github.com/b3nj5m1n/xdg-ninja.git",
        "deps": "",
        "build": "install -Dm755 xdg-ninja.sh /usr/local/bin/xdg-ninja && cp -r scripts /usr/local/share/xdg-ninja/",
    },
    "pixora-icons-git": {
        "repo": "",  # user's custom icon theme
        "deps": "",
        "build": "# Copy icon dirs from PKGBUILD source to /usr/share/icons/",
    },
    "hxd": {
        "repo": "https://github.com/schievel/hxd.git",
        "deps": "gcc make lua-devel scdoc",
        "build": "make && make install",
    },
    "fennel": {
        "repo": "",
        "deps": "",
        "build": "curl -sLo /usr/local/bin/fennel https://fennel-lang.org/downloads/fennel-1.6.1 && chmod +x /usr/local/bin/fennel",
    },
    "ytsurf": {
        "repo": "https://github.com/irevenko/ytsurf.git",
        "deps": "golang",
        "build": "go build -o ytsurf cmd/ytsurf/main.go && install -m755 ytsurf /usr/local/bin/",
    },
    "newsraft": {
        "repo": "https://github.com/newsraft/newsraft.git",
        "deps": "gcc make ncurses-devel libcurl-devel expat-devel sqlite-devel",
        "build": "make && make install",
    },
    "oports-git": {
        "repo": "",  # user's custom tool
        "deps": "",
        "build": "# User-specific port tool — copy from PKGBUILD",
    },
    "tanin-git": {
        "repo": "https://github.com/kamiyaa/tanin.git",
        "deps": "cargo alsa-lib-devel openssl-devel",
        "build": "cargo build --release --no-default-features && install -m755 target/release/tanin /usr/local/bin/",
    },
}


def gen_containerfile_additions():
    """Generate additional Containerfile lines to append."""
    lines = []
    lines.append("")
    lines.append("# ═══════════════════════════════════════════════════════════")
    lines.append("# EXTENSIONS: missed RPMs, COPR, npm, extra cargo/pip/go")
    lines.append("# Generated by extras.py")
    lines.append("# ═══════════════════════════════════════════════════════════")
    lines.append("")

    # ── RPM additions ───────────────────────────────────────────
    ALL_EXTRA_RPMS = [
        "amneziawg-dkms",
        "amneziawg-tools",
        "cosmic-greeter",
        "google-chrome-stable",
        "satty",
        "sing-box",
        "swayosd",
        "v2raya",
    ]

    # Google Chrome repo
    if GOOGLE_CHROME:
        lines.append("# ── Google Chrome RPM repo ──────────────────────────────")
        lines.append("RUN cat > /etc/yum.repos.d/google-chrome.repo <<'EOF'")
        lines.append("[google-chrome]")
        lines.append("name=google-chrome")
        lines.append("baseurl=https://dl.google.com/linux/chrome/rpm/stable/x86_64")
        lines.append("enabled=1")
        lines.append("gpgcheck=1")
        lines.append("gpgkey=https://dl.google.com/linux/linux_signing_key.pub")
        lines.append("EOF")
        lines.append("")

    # COPR repos (deduplicated by repo path)
    if COPR_REPOS:
        lines.append("# ── COPR repos ──────────────────────────────────────────")
        seen = set()
        for _pkg, copr_path in sorted(COPR_REPOS.items()):
            if copr_path in seen:
                continue
            seen.add(copr_path)
            user, repo = copr_path.split("/")
            lines.append(
                f"RUN curl -sLo /etc/yum.repos.d/_copr_{user}-{repo}.repo \\"
            )
            lines.append(
                f"    https://copr.fedorainfracloud.org/coprs/{copr_path}/repo/fedora-$(rpm -E %fedora)/{user}-{repo}-fedora-$(rpm -E %fedora).repo"
            )
        lines.append("")

    # Extra RPM install (one RUN)
    if ALL_EXTRA_RPMS:
        lines.append(f"# ── Extra RPMs ({len(ALL_EXTRA_RPMS)} total) ────────────")
        lines.append("RUN rpm-ostree install -y \\")
        for i, pkg in enumerate(sorted(set(ALL_EXTRA_RPMS))):
            suffix = " \\" if i < len(ALL_EXTRA_RPMS) - 1 else " && \\"
            lines.append(f"    {pkg}{suffix}")
        lines.append("    rpm-ostree cleanup -m")
        lines.append("")

    # ── NPM ──────────────────────────────────────────────────────
    if NPM_PKGS:
        lines.append(f"# ── NPM global ({len(NPM_PKGS)} total) ──────────────────")
        npm_args = " ".join(NPM_PKGS)
        lines.append(f"RUN npm install -g {npm_args}")
        lines.append("")

    # ── Extra Cargo ──────────────────────────────────────────────
    cargo_filtered = [c for c in EXTRA_CARGO]
    if cargo_filtered:
        lines.append(f"# ── Extra Cargo ({len(cargo_filtered)} total) ────────────")
        lines.append("RUN cargo binstall -y " + " ".join(cargo_filtered))
        lines.append("")

    # ── Extra Pip ────────────────────────────────────────────────
    if EXTRA_PIP:
        lines.append(f"# ── Extra Pip ({len(EXTRA_PIP)} total) ───────────────────")
        lines.append("RUN pipx install " + " ".join(EXTRA_PIP))
        lines.append("")

    # ── Extra Go ─────────────────────────────────────────────────
    if EXTRA_GO:
        lines.append(f"# ── Extra Go ({len(EXTRA_GO)} total) ─────────────────────")
        for _name, path in EXTRA_GO.items():
            lines.append(f"RUN go install {path}")
        lines.append("")

    # ── Binary downloads ─────────────────────────────────────────
    if BINARIES:
        lines.append(f"# ── Binary downloads ({len(BINARIES)} total) ─────────────")
        lines.append("RUN mkdir -p /tmp/bin-dl && \\")
        lines.append("    dnf install -y curl jq tar unzip gzip && \\")
        # One script per binary
        for name, (repo, _bin, pattern) in sorted(BINARIES.items()):
            if pattern:
                download_cmd = (
                    f'curl -sL "$(curl -sL "https://api.github.com/repos/{repo}/releases/latest"'
                    f' | jq -r \'.assets[].browser_download_url\''
                    f' | grep -i \'linux.*amd64\\|Linux_x86_64\\|linux_x64\')"'
                    f' -o /tmp/bin-dl/{name}.dl'
                )
                lines.append(
                    f"    {download_cmd} && \\"
                )
                lines.append(
                    f"    (tar xf /tmp/bin-dl/{name}.dl -C /tmp/bin-dl/ 2>/dev/null"
                    f" || unzip -o /tmp/bin-dl/{name}.dl -d /tmp/bin-dl/) && \\"
                )
                lines.append(
                    f"    find /tmp/bin-dl/ -type f -name '{_bin}' -executable"
                    f" -exec install -m755 {{}} /usr/local/bin/ \\; && \\"
                )
        lines.append("    rm -rf /tmp/bin-dl")
        lines.append("")

    # ── Source builds ────────────────────────────────────────────
    if SOURCE_BUILDS:
        lines.append(f"# ── Source builds ({len(SOURCE_BUILDS)} total) ───────────")
        for name, info in sorted(SOURCE_BUILDS.items()):
            repo = info["repo"]
            deps = info["deps"]
            build = info["build"]
            if repo and build:
                lines.append(f"# {name}")
                if deps:
                    lines.append(f"RUN dnf install -y {deps} && \\")
                    lines.append(f"    git clone --depth=1 {repo} /tmp/build-{name} && \\")
                else:
                    lines.append(f"RUN git clone --depth=1 {repo} /tmp/build-{name} && \\")
                lines.append(f"    cd /tmp/build-{name} && \\")
                lines.append(f"    {build} && \\")
                lines.append(f"    rm -rf /tmp/build-{name}")
                lines.append("")

    return "\n".join(lines)


def main():
    additions = gen_containerfile_additions()
    outfile = Path(__file__).resolve().parent / "Containerfile.extras"
    outfile.write_text(additions)
    print(f"Wrote {outfile} ({len(additions.splitlines())} lines)")
    print()
    print("Instructions:")
    print("  1. Ensure the main Containerfile has been generated by generate-bluefin-image.py")
    print("  2. Insert the contents of Containerfile.extras after the RPM section")
    print("     (before the Flatpak section)")
    print("  3. Or: merge manually into Containerfile")


if __name__ == "__main__":
    main()
