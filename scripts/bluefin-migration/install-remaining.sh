#!/bin/bash
# Post-install script for bluefin-custom image
# Run AFTER deploying the image to real hardware (or in a VM with networking)
# Installs: COPR repos, flatpak, cargo, pip, go, npm, binaries, source builds
set -euo pipefail

echo "=== bluefin-custom post-install ==="
echo "This will install the remaining packages that couldn't be included"
echo "in the Containerfile build (network-dependent layers)."
echo ""

# ── 1. COPR repos ──────────────────────────────────────────────────
echo "── Adding COPR repos ──"

# Hyprland (essential — the user's main compositor)
sudo dnf copr enable -y solopasha/hyprland
# Packages: hyprland, hypridle, hyprlock, hyprpicker, hyprpolkitagent, xdg-desktop-portal-hyprland

# Additional COPRs
sudo dnf copr enable -y errornointernet/packages        # satty
sudo dnf copr enable -y erikreider/SwayNotificationCenter # swayosd

echo "── Installing COPR packages ──"
sudo dnf install -y \
    hyprland hypridle hyprlock hyprpicker hyprpolkitagent \
    xdg-desktop-portal-hyprland \
    satty swayosd \
    || echo "(some COPR packages may not be available)"

# ── 2. Flatpak ─────────────────────────────────────────────────────
echo "── Installing Flatpak apps ──"
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

flatpak install -y flathub \
    org.mozilla.firefox \
    org.chromium.Chromium \
    org.gimp.GIMP \
    org.blender.Blender \
    org.telegram.desktop \
    org.localsend.localsend_app \
    app.zen_browser.zen \
    net.lutris.Lutris \
    com.rawtherapee.RawTherapee \
    com.dosbox.DOSBox \
    || echo "(network issues — retry later)"

# ── 3. Cargo ───────────────────────────────────────────────────────
echo "── Installing Rust CLI tools (cargo) ──"
cargo install cargo-binstall  # faster binary installs

cargo binstall -y \
    bandwhich bat bottom difftastic doggo dust erdtree eza \
    fclones fd genact git-delta grex helix hexyl himalaya \
    htmlq hyperfine just no-more-secrets onefetch ouch pastel \
    ripgrep rmpc tealdeer television xh yazi yt-dlp zellij zoxide \
    || cargo install \
    bandwhich bat bottom difftastic doggo dust erdtree eza \
    fclones fd genact git-delta grex helix hexyl himalaya \
    htmlq hyperfine just no-more-secrets onefetch ouch pastel \
    ripgrep rmpc tealdeer television xh yazi yt-dlp zellij zoxide

# Extra cargo packages (from UNAVAILABLE list)
cargo binstall -y \
    amdgpu_top hyprscratch lutgen regex-tui rustmission \
    systemd-manager-tui youtube-tui otter-launcher wlr-which-key \
    oyo tmmpr \
    || cargo install \
    amdgpu_top hyprscratch lutgen regex-tui rustmission \
    systemd-manager-tui youtube-tui otter-launcher wlr-which-key \
    oyo tmmpr

# ── 4. Pip/Pipx ───────────────────────────────────────────────────
echo "── Installing Python tools (pipx) ──"
pipx install beets gallery-dl httpie jupyterlab pre-commit \
    python-ascii_magic python-faker python-internetarchive \
    python-numpy python-orjson python-poetry python-pyperclip \
    python-rapidgzip python-telethon python-textual ruff \
    s-tui streamlink vale yamllint

pipx install cmake-language-server dool epr-reader mpDris2 patool \
    protonvpn-cli raysession

# ── 5. Go ─────────────────────────────────────────────────────────
echo "── Installing Go tools ──"
go install github.com/containerd/nerdctl@latest
go install github.com/Mic92/ssh-to-age/cmd/ssh-to-age@latest
go install github.com/boyter/scc/v3@latest
go install github.com/laurent22/massren@latest
go install github.com/derat/unflac@latest

# ── 6. NPM ────────────────────────────────────────────────────────
echo "── Installing NPM packages ──"
npm install -g @anthropic-ai/claude-code

# ── 7. Binary downloads (pre-built tools from GitHub) ─────────────
echo "── Downloading pre-built binaries ──"
mkdir -p /tmp/bin-dl

download_binary() {
    local name="$1" repo="$2" binary="$3"
    echo "  Downloading $name from $repo..."
    local url
    url=$(curl -sL "https://api.github.com/repos/${repo}/releases/latest" \
        | jq -r '.assets[].browser_download_url' \
        | grep -i 'linux.*amd64\|linux.*x86_64\|Linux_x86_64\|linux_x64' \
        | head -1)
    if [ -n "$url" ]; then
        curl -sLo "/tmp/bin-dl/${name}.dl" "$url"
        tar xf "/tmp/bin-dl/${name}.dl" -C /tmp/bin-dl/ 2>/dev/null || \
            unzip -o "/tmp/bin-dl/${name}.dl" -d /tmp/bin-dl/ 2>/dev/null
        find /tmp/bin-dl/ -type f -name "${binary}" -executable \
            -exec sudo install -m755 {} /usr/local/bin/ \;
    else
        echo "    WARNING: Could not find download URL for $name"
    fi
}

download_binary aliae        "JanDeDobbeleer/aliae"        "aliae"
download_binary carapace     "carapace-sh/carapace-bin"    "carapace"
download_binary freeze       "charmbracelet/freeze"        "freeze"
download_binary hishtory     "ddworken/hishtory"           "hishtory"
download_binary pup          "ericchiang/pup"              "pup"
download_binary sing-box     "SagerNet/sing-box"           "sing-box"
download_binary strace-tui   "nickelc/strace-tui"         "strace-tui"
download_binary v2raya       "v2rayA/v2rayA"              "v2raya"
download_binary watchtower   "containrrr/watchtower"       "watchtower"
download_binary gowall       "Achno/gowall"               "gowall"
download_binary eilmeldung   "qcasey/eilmeldung"          "eilmeldung"
download_binary reddix       "crosstype/reddix"           "reddix"
download_binary simutil      "google/simutil"             "simutil"
download_binary witr         "siddharthroy12/witr"        "witr"

rm -rf /tmp/bin-dl

# ── 8. Source builds (git clone + make) ───────────────────────────
echo "── Building from source ──"
TMPDIR=$(mktemp -d)

build_from_source() {
    local name="$1" repo="$2" deps="$3" build_cmds="$4"
    echo "  Building $name from $repo..."
    [ -n "$deps" ] && sudo dnf install -y $deps
    git clone --depth=1 "$repo" "$TMPDIR/$name"
    cd "$TMPDIR/$name"
    eval "$build_cmds"
    cd /
}

build_from_source bucklespring "https://github.com/zevv/bucklespring.git" \
    "gcc make libpulse-devel libxtst-devel" \
    "make && sudo install -m755 buckle /usr/local/bin/"
build_from_source dualsensectl "https://github.com/nowrep/dualsensectl.git" \
    "gcc meson ninja-build pkgconfig(sdl2) pkgconfig(libudev) pkgconfig(dbus-1) pkgconfig(hidapi-hidraw)" \
    "meson setup builddir && ninja -C builddir && sudo ninja -C builddir install"
build_from_source mpdas "https://github.com/hrkfdn/mpdas.git" \
    "gcc gcc-c++ make libcurl-devel libmpdclient-devel" \
    "make && sudo install -m755 mpdas /usr/local/bin/"
build_from_source neo-matrix "https://github.com/st3w/neo.git" \
    "gcc make autoconf automake ncurses-devel" \
    "autoreconf -fi && ./configure && make && sudo make install"
build_from_source pipemixer "https://github.com/nickelc/pipemixer.git" \
    "gcc meson ninja-build pipewire-devel ncurses-devel" \
    "meson setup builddir && ninja -C builddir && sudo ninja -C builddir install"
build_from_source newsraft "https://github.com/newsraft/newsraft.git" \
    "gcc make ncurses-devel libcurl-devel expat-devel sqlite-devel" \
    "make && sudo make install"
build_from_source rofi-fbe "https://github.com/marvinkreis/rofi-file-browser-extended.git" \
    "gcc cmake make rofi-devel" \
    "mkdir build && cd build && cmake .. && make && sudo make install"
build_from_source tessen "https://github.com/ayushnix/tessen.git" \
    "" \
    "sudo PREFIX=/usr/local make install"
build_from_source xdg-ninja "https://github.com/b3nj5m1n/xdg-ninja.git" \
    "" \
    "sudo install -Dm755 xdg-ninja.sh /usr/local/bin/xdg-ninja && sudo cp -r scripts /usr/local/share/xdg-ninja/"
build_from_source zapret2 "https://github.com/bol-van/zapret.git" \
    "gcc make" \
    "cd ip2net && make && sudo install -m755 ip2net /usr/local/bin/"

# fennel — static binary
sudo curl -sLo /usr/local/bin/fennel https://fennel-lang.org/downloads/fennel-1.6.1
sudo chmod +x /usr/local/bin/fennel

rm -rf "$TMPDIR"

# ── 9. Custom packages (user's own PKGBUILDs) ──────────────────────
echo "── Custom packages (need manual porting) ──"
echo "  The following packages need to be ported from Arch PKGBUILDs:"
echo "    albumdetails, richcolors, taoup, proxypilot, neg-pretty-printer"
echo "    wl, raise, ssh-to-age, iosevka-neg-fonts"
echo "  Place build scripts in ~/src/cfg/scripts/bluefin-migration/custom/"
echo ""

echo "=== Post-install complete ==="
echo "Total packages installed: $(rpm -qa | wc -l) RPMs + flatpak + cargo + pip + go"
echo ""
echo "Remaining unavailable packages (~30):"
echo "  Arch-specific (skip): base, base-devel, linux*, limine, pacman-contrib, paru, etc."
echo "  Custom PKGBUILD: 11 packages — port manually"
echo "  Truly unavailable: amdgpu-vulkan-switcher-git, gvfs-*, optiscaler, quickshell, vicinae-bin, etc."
