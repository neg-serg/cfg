#!/bin/bash
# Reproducible host-build script for bluefin-custom-full
# Reads packages.yaml, builds everything not in RPM list, outputs to build-output/
set -euo pipefail

OUTDIR="${1:-/tmp/hyprland-binaries}"
mkdir -p "$OUTDIR/usr/bin" "$OUTDIR/usr/lib64" "$OUTDIR/usr/share"

# ── Helper functions ──────────────────────────────────────────────

cargo_install() { cargo install --root "$OUTDIR/usr" "$@" 2>/dev/null; }
go_install()   { GOBIN="$OUTDIR/usr/bin" go install "$@" 2>/dev/null; }
pip_install()  { pip install --prefix="$OUTDIR/usr" "$@" 2>/dev/null; }
npm_install()  { npm install --prefix="$OUTDIR/usr" -g "$@" 2>/dev/null; }
git_clone()    { git clone --depth=1 "https://github.com/$1" /tmp/git-"${1#*/}" 2>/dev/null; }

copy_binary() {
  local src="$1" dst="${2:-$(basename "$1")}"
  cp "$src" "$OUTDIR/usr/bin/$dst" 2>/dev/null
}

bundle_libs() {
  local bin="$1"
  ldd "$bin" 2>/dev/null | grep -oP '/\S+' | while read lib; do
    case "$lib" in */libc.so*|*/libm.so*|*/libdl*|*/libpthread*|*/librt*|*/ld-linux*|*/libstdc++*|*/libgcc_s*|*/libresolv*) continue; esac
    cp -n "$lib" "$OUTDIR/usr/lib64/" 2>/dev/null
  done
}

# ── Hyprland ecosystem ─────────────────────────────────────────────

build_hyprland() {
  echo "=== Hyprland ==="
  local WORK=/tmp/hypr-build && rm -rf "$WORK" && mkdir -p "$WORK" && cd "$WORK"
  
  for pkg in \
    "hyprutils|hyprwm/hyprutils" \
    "hyprlang|hyprwm/hyprlang" \
    "hyprcursor|hyprwm/hyprcursor" \
    "hyprwayland-scanner|hyprwm/hyprwayland-scanner" \
    "hyprgraphics|hyprwm/hyprgraphics"; do
    name="${pkg%%|*}"; repo="${pkg##*|}"
    git clone --depth=1 "https://github.com/$repo" "$name" 2>/dev/null || continue
    cd "$name" && cmake -B b -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr 2>/dev/null && cmake --build b -j$(nproc) 2>/dev/null && cmake --install b --prefix /usr 2>/dev/null || DESTDIR="$OUTDIR" cmake --install b 2>/dev/null
    cd "$WORK"
  done

  # aquamarine
  git clone --depth=1 https://github.com/hyprwm/aquamarine && cd aquamarine && cmake -B b -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr && cmake --build b -j$(nproc) && DESTDIR="$OUTDIR" cmake --install b && cd "$WORK"

  # Hyprland
  git clone --depth=1 --recursive https://github.com/hyprwm/Hyprland && cd Hyprland && cmake -B b -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr && cmake --build b -j$(nproc) && DESTDIR="$OUTDIR" cmake --install b && cd "$WORK"
  copy_binary "$WORK/Hyprland/b/Hyprland"
  
  # hyprland-protocols
  git clone --depth=1 https://github.com/hyprwm/hyprland-protocols && cd hyprland-protocols && cmake -B b -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr && cmake --build b && DESTDIR="$OUTDIR" cmake --install b && cd "$WORK"

  # Components
  for comp in hypridle hyprlock hyprpicker hyprpolkitagent xdg-desktop-portal-hyprland; do
    git clone --depth=1 "https://github.com/hyprwm/$comp" && cd "$comp" && cmake -B b -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr && cmake --build b -j$(nproc) && copy_binary "b/$comp" && cd "$WORK"
  done

  copy_binary /usr/bin/hyprctl 2>/dev/null || true
  copy_binary /usr/bin/uwsm 2>/dev/null || true
  rm -rf "$WORK"
}

# ── Cargo batch ────────────────────────────────────────────────────

build_cargo() {
  echo "=== Cargo packages ==="
  local pkgs="bat bottom eza fd-find du-dust erdtree fclones hexyl hyperfine just bandwhich doggo grex htmlq difftastic choose genact himalaya gist zellij xh viu ouch curlie ripgrep rmpc broot ctop kmon git-delta pastel onefetch television sbctl"
  cargo_install $pkgs
  cargo_install hyprscratch amdgpu_top lutgen regex-tui rustmission systemd-manager-tui youtube-tui otter-launcher wlr-which-key oyo tmmpr songfetch
  cargo_install jj 2>/dev/null || cargo install --root "$OUTDIR/usr" --locked --bin jj jj-cli 2>/dev/null
}

# ── Go packages ────────────────────────────────────────────────────

build_go() {
  echo "=== Go packages ==="
  go_install github.com/containerd/nerdctl@latest
  go_install github.com/Mic92/ssh-to-age/cmd/ssh-to-age@latest
  go_install github.com/boyter/scc/v3@latest
  go_install github.com/laurent22/massren@latest
  go_install github.com/derat/unflac@latest
  go_install github.com/gitleaks/gitleaks/v8@latest
  go_install github.com/wagoodman/dive@latest
  go_install github.com/nektos/act@latest
}

# ── Git clone + build ──────────────────────────────────────────────

build_git() {
  echo "=== Source builds ==="
  git clone --depth=1 https://github.com/zevv/bucklespring /tmp/gb && cd /tmp/gb && make && copy_binary /tmp/gb/buckle && cd /
  git clone --depth=1 https://github.com/st3w/neo /tmp/neo && cd /tmp/neo && autoreconf -fi && ./configure && make && make install DESTDIR="$OUTDIR" && cd /
  git clone --depth=1 https://github.com/bol-van/zapret /tmp/zapret && cd /tmp/zapret/ip2net && make && copy_binary /tmp/zapret/ip2net/ip2net && cd /
  git clone --depth=1 https://github.com/b3nj5m1n/xdg-ninja /tmp/xdg && copy_binary /tmp/xdg/xdg-ninja.sh xdg-ninja && cd /
  git clone --depth=1 https://github.com/ayushnix/tessen /tmp/tessen && cd /tmp/tessen && make install PREFIX="$OUTDIR/usr" && cd /
  git clone --depth=1 https://github.com/newsraft/newsraft /tmp/newsraft && cd /tmp/newsraft && make && copy_binary /tmp/newsraft/newsraft && cd /
  git clone --depth=1 https://github.com/hrkfdn/mpdas /tmp/mpdas && cd /tmp/mpdas && make && copy_binary /tmp/mpdas/mpdas && cd /
  git clone --depth=1 https://github.com/nowrep/dualsensectl /tmp/ds && cd /tmp/ds && meson setup b && ninja -C b && copy_binary /tmp/ds/b/dualsensectl && cd /
  git clone --depth=1 https://github.com/unkn0wn-root/resterm /tmp/resterm && cd /tmp/resterm && go build -o resterm ./cmd/resterm/ && copy_binary /tmp/resterm/resterm && cd /
  git clone --depth=1 https://github.com/raaymax/lazytail /tmp/lazytail && cd /tmp/lazytail && cargo build --release && copy_binary /tmp/lazytail/target/release/lazytail && cd /
  git clone --depth=1 https://github.com/ck-zhang/reddix /tmp/reddix && cd /tmp/reddix && cargo build --release && copy_binary /tmp/reddix/target/release/reddix && cd /
  curl -sLo "$OUTDIR/usr/bin/fennel" https://fennel-lang.org/downloads/fennel-1.6.1 && chmod +x "$OUTDIR/usr/bin/fennel"
}

# ── Binary downloads ───────────────────────────────────────────────

build_downloads() {
  echo "=== Binary downloads ==="
  local dl_dir=/tmp/dl && mkdir -p "$dl_dir"
  
  dl_github() { local n="$1" r="$2" b="${3:-$1}"; curl -fsSL --max-time 60 "https://api.github.com/repos/$r/releases/latest" 2>/dev/null | jq -r '.assets[].browser_download_url' | grep -i 'linux.*amd64\|linux.*x86_64\|Linux_x86_64\|linux.*x64' | head -1 | xargs curl -fsSL --max-time 120 -o "$dl_dir/$n.dl" 2>/dev/null && (tar xf "$dl_dir/$n.dl" -C "$dl_dir/" 2>/dev/null || unzip -o "$dl_dir/$n.dl" -d "$dl_dir/") && find "$dl_dir" -maxdepth 3 -name "$b" -type f -executable -exec cp {} "$OUTDIR/usr/bin/" \;; }

  dl_github aliae      "JanDeDobbeleer/aliae"
  dl_github carapace   "carapace-sh/carapace-bin" "carapace"
  dl_github freeze     "charmbracelet/freeze"
  dl_github hishtory   "ddworken/hishtory"
  dl_github pup        "ericchiang/pup"
  dl_github sing-box   "SagerNet/sing-box"
  dl_github strace-tui "nickelc/strace-tui"
  dl_github v2raya     "v2rayA/v2rayA"
  dl_github watchtower "containrrr/watchtower"
  dl_github gowall     "Achno/gowall"
  dl_github eilmeldung "qcasey/eilmeldung"
  dl_github FlClash    "chen08209/FlClash" "FlClash"
  dl_github localsend  "localsend/localsend"
  dl_github hw-probe   "linuxhw/hw-probe"
  dl_github babashka   "babashka/babashka" "bb"
  dl_github oh-my-posh "JanDeDobbeleer/oh-my-posh"
  dl_github repeater   "shaankhosla/repeater" "repeater-x86_64-unknown-linux-gnu.tar.xz"
  dl_github simutil    "dungngminh/simutil"
  dl_github witr       "rewrite-everything-in-rust/witr-rs" "witr"
  dl_github act        "nektos/act"

  # v2rayn — Linux RPM from GitHub
  curl -fsSL --max-time 60 -o "$dl_dir/v2rayn.rpm" "https://github.com/2dust/v2rayN/releases/latest/download/v2rayN-linux-rhel-64.rpm" 2>/dev/null && cd "$OUTDIR" && bsdtar xf "$dl_dir/v2rayn.rpm" 2>/dev/null && cd /
  
  # zen-browser
  dl_github zen-browser "zen-browser/desktop" "zen-browser"
  cp "$OUTDIR/usr/bin/zen-browser" "$OUTDIR/usr/bin/zen-browser.AppImage" 2>/dev/null || true
  
  # google-chrome
  curl -fsSL --max-time 120 -o "$dl_dir/chrome.rpm" "https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm" 2>/dev/null && cd "$OUTDIR" && bsdtar xf "$dl_dir/chrome.rpm" 2>/dev/null && cd / && cp "$OUTDIR/opt/google/chrome/google-chrome" "$OUTDIR/usr/bin/" 2>/dev/null || true

  # optiscaler
  curl -fsSL --max-time 60 "https://api.github.com/repos/optiscaler/optiscaler/releases/latest" 2>/dev/null | jq -r '.assets[].browser_download_url' | head -1 | xargs curl -fsSL --max-time 120 -o "$dl_dir/optiscaler.7z" 2>/dev/null && mkdir -p "$OUTDIR/opt/optiscaler" && 7z x "$dl_dir/optiscaler.7z" -o"$OUTDIR/opt/optiscaler" -y 2>/dev/null || true

  # steam — copy from host
  copy_binary /usr/bin/steam 2>/dev/null || true
  cp -a /usr/lib/steam "$OUTDIR/usr/lib/" 2>/dev/null || true
  cp -a /usr/lib32 "$OUTDIR/usr/lib32" 2>/dev/null || true
  
  rm -rf "$dl_dir"
}

# ── NPM ────────────────────────────────────────────────────────────

build_npm() {
  echo "=== NPM ==="
  npm_install @anthropic-ai/claude-code
  find "$OUTDIR/usr/lib/node_modules" -name "claude" -type f -executable -exec cp {} "$OUTDIR/usr/bin/claude-code" \; 2>/dev/null || true
  npm_install @i7m/instagram-cli 2>/dev/null || true
}

# ── Copy from host (things already installed) ──────────────────────

copy_from_host() {
  echo "=== Copy from host ==="
  for bin in taoup raise proxypilot richcolors neg-pretty-printer albumdetails sidecar throne tailray duf swayimg ghgrab gmap handlr hermes vk_amdvlk vk_legacy vk_pro vk_radv vicinae wl-daemon wl fsel fselect ghg gowall pup hishtory freeze watchtower eilmeldung aliae carapace strace-tui sing-box FlClash v2raya zen-browser.AppImage bb babashka cpufetch gallery-dl cmake-language-server bazecor patool unflac songfetch regex-tui mpdris2 raysession protonvpn nms sops ghostty yazi zk tv oh-my-posh lutgen gitleaks act hw-probe google-chrome localsend curlie resterm lazytail reddix witr repeater simutil v2rayN; do
    [ -f "$OUTDIR/usr/bin/$bin" ] && continue
    path=$(command -v $bin 2>/dev/null) && copy_binary "$path" "$bin" && bundle_libs "$path" && echo "  $bin"
  done
}

# ── Main ───────────────────────────────────────────────────────────

echo "Building all packages for bluefin-custom-full..."
echo "Output: $OUTDIR"

build_hyprland
build_cargo
build_go
build_git
build_downloads
build_npm
copy_from_host

# Bundle shared libs for all binaries
echo "=== Bundling shared libs ==="
for bin in "$OUTDIR"/usr/bin/*; do
  [ -f "$bin" ] && [ -x "$bin" ] && bundle_libs "$bin"
done

count=$(find "$OUTDIR/usr/bin" -type f | wc -l)
echo "=== Done: $count binaries ==="
