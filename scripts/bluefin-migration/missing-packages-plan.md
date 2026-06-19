# Missing Packages Build Plan for Bluefin Custom Image

107 Arch/AUR packages with no direct Fedora RPM mapping.
Organized by installation strategy.

---

## 1. SKIP — Arch-Specific / Not Applicable on Fedora (12 packages)

These are Arch ecosystem packages with no meaning on Fedora:

| Package | Reason |
|---|---|
| `base` | Arch meta-package; Fedora has its own base |
| `base-devel` | Use `@development-tools` group (already in bluefin-dx) |
| `linux` | Fedora ships its own kernel |
| `linux-headers` | Use `kernel-devel` RPM |
| `linux-cachyos-headers` | CachyOS-specific; use `kernel-devel` |
| `limine` | Arch bootloader; Fedora uses GRUB/systemd-boot |
| `pacman-contrib` | pacman utilities — no pacman on Fedora |
| `paru` | AUR helper — no AUR on Fedora |
| `paru-debug` | AUR helper debug symbols |
| `rebuild-detector` | Arch rebuild checker — not applicable |
| `rofi-file-browser-extended-git-debug` | Debug symbols only — skip |
| `systemd-resolvconf` | On Fedora: `ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf` |

---

## 2. RPM — Available in Fedora Repos (Mapping Missed) (8 packages)

These actually exist as Fedora RPMs:

| Arch Package | Fedora RPM | Notes |
|---|---|---|
| `dcfldd` | `dcfldd` | In Fedora repos |
| `nethack` | `nethack` | In Fedora repos |
| `rmlint` | `rmlint` | In Fedora repos |
| `swappy` | `swappy` | In Fedora repos |
| `ttfautohint` | `ttfautohint` | In Fedora repos |
| `wlogout` | `wlogout` | In Fedora repos |
| `lib32-vulkan-radeon` | `mesa-vulkan-drivers.i686` | 32-bit Mesa Vulkan |
| `lib32-amdvlk-bin` | `amdvlk.i686` | 32-bit AMDVLK (if available) or skip |

**Action**: Add to `rpm-ostree install` list.

---

## 3. Google Chrome RPM Repo (1 package)

| Package | Strategy |
|---|---|
| `google-chrome` | Add Google's official RPM repo |

```dockerfile
RUN cat > /etc/yum.repos.d/google-chrome.repo <<'EOF'
[google-chrome]
name=google-chrome
baseurl=https://dl.google.com/linux/chrome/rpm/stable/x86_64
enabled=1
gpgcheck=1
gpgkey=https://dl.google.com/linux/linux_signing_key.pub
EOF
RUN rpm-ostree install google-chrome-stable
```

---

## 4. COPR Repos (10 packages)

| Package | COPR / Repo | Install |
|---|---|---|
| `swayosd` | `copr:copr.fedorainfracloud.org:erikreider:SwayNotificationCenter` or build | `rpm-ostree install swayosd` |
| `satty` | `copr:copr.fedorainfracloud.org:errornointernet:packages` | `rpm-ostree install satty` |
| `v2raya-bin` | `copr:copr.fedorainfracloud.org:nicknamenull:v2raya` | `rpm-ostree install v2raya` |
| `sing-box-bin` | `copr:copr.fedorainfracloud.org:duament:sing-box` | `rpm-ostree install sing-box` |
| `cosmic-greeter` | `copr:copr.fedorainfracloud.org:ryanabx:cosmic-epoch` | COSMIC DE stack — large dependency |
| `proton-vpn-cli` | PyPI: `pip install protonvpn-cli` | Or use official Proton RPM repo |
| `amneziawg-dkms` | `copr:copr.fedorainfracloud.org:amneziavpn:amneziawg` | DKMS kernel module |
| `amneziawg-tools` | `copr:copr.fedorainfracloud.org:amneziavpn:amneziawg` | Userspace tools |
| `ollama-vulkan` | Standard `ollama` RPM already includes Vulkan support | Skip if ollama is installed |
| `wlr-which-key` | May need COPR or source build | Check `copr search wlr-which-key` |

**Action**: Add COPR repos in Containerfile, then `rpm-ostree install`.

```dockerfile
RUN curl -sLo /etc/yum.repos.d/_copr_v2raya.repo \
    https://copr.fedorainfracloud.org/coprs/nicknamenull/v2raya/repo/fedora-$(rpm -E %fedora)/
RUN curl -sLo /etc/yum.repos.d/_copr_amneziawg.repo \
    https://copr.fedorainfracloud.org/coprs/amneziavpn/amneziawg/repo/fedora-$(rpm -E %fedora)/
RUN curl -sLo /etc/yum.repos.d/_copr_sing-box.repo \
    https://copr.fedorainfracloud.org/coprs/duament/sing-box/repo/fedora-$(rpm -E %fedora)/
```

---

## 5. NPM Global Install (2 packages)

| Package | Command |
|---|---|
| `claude-code` | `npm install -g @anthropic-ai/claude-code` |
| `instagram-cli` | `npm install -g instagram-cli` (if still maintained) |

---

## 6. Pip / Pipx Install (6 packages)

| Package | Command | Notes |
|---|---|---|
| `cmake-language-server` | `pipx install cmake-language-server` | Python LSP |
| `dool` | `pipx install dool` | dstat fork, pure Python |
| `epr-git` | `pipx install epr-reader` | Terminal e-book reader |
| `mpdris2-git` | `pipx install mpDris2` | MPD MPRIS2 bridge |
| `patool` | `pipx install patool` | Archive manager |
| `raysession` | `pipx install raysession` | JACK/PW session manager |

---

## 7. Cargo Install — Rust Packages (8 packages)

| Package | Crate | Command |
|---|---|---|
| `amdgpu_top` | `amdgpu_top` | `cargo install amdgpu_top` |
| `lutgen-bin` | `lutgen` | `cargo install lutgen` |
| `regex-tui` | `regex-tui` | `cargo install regex-tui` |
| `rustmission` | `rustmission` | `cargo install rustmission` |
| `systemd-manager-tui` | `sysz` or source | `cargo install sysz` |
| `youtube-tui` | `youtube-tui` | `cargo install youtube-tui` |
| `hyprscratch` | `hyprscratch` | `cargo install hyprscratch` |
| `newsraft` | N/A — C project | **Moved to source build** |

**Add to existing cargo binstall line in Containerfile.**

---

## 8. Go Install (5 packages)

| Package | Go Path | Command |
|---|---|---|
| `ssh-to-age` | `github.com/Mic92/ssh-to-age/cmd/ssh-to-age` | `go install ...@latest` |
| `scc` | `github.com/boyter/scc/v3` | `go install ...@latest` |
| `massren` | `github.com/laurent22/massren` | `go install ...@latest` |
| `unflac` | `github.com/derat/unflac` | `go install ...@latest` |
| `gowall-bin` | `github.com/Achno/gowall` | `go install ...@latest` |

---

## 9. Binary Downloads from GitHub Releases (24 packages)

All `-bin` suffix packages — download pre-built binary, verify checksum, install to `/usr/local/bin`.

| Package | GitHub Repo | Binary |
|---|---|---|
| `aliae-bin` | `JanDeDobbeleer/aliae` | Linux amd64 tarball |
| `carapace-bin` | `carapace-sh/carapace-bin` | Linux amd64 tarball |
| `eilmeldung-bin` | Research needed | Binary |
| `flclashx-bin` | `chen08209/FlClash` | AppImage or binary |
| `freeze-bin` | `charmbracelet/freeze` | Linux amd64 tarball |
| `fsel-bin` | Research needed | Binary |
| `ghgrab-bin` | Research needed | Binary |
| `gmap-bin` | Research needed | Binary |
| `hishtory-bin` | `ddworken/hishtory` | Linux amd64 binary |
| `lazytail-bin` | Research needed | Binary |
| `pup-bin` | `ericchiang/pup` | Linux amd64 binary |
| `reddix-bin` | Research needed | Binary |
| `repeater-bin` | Research needed | Binary |
| `resterm-bin` | Research needed | Binary |
| `simutil-bin` | Research needed | Binary |
| `strace-tui-bin` | `nickelc/strace-tui` | Binary |
| `v2rayn-bin` | `2dust/v2rayN` | Linux binary |
| `watchtower-bin` | `containrrr/watchtower` | Linux amd64 binary |
| `witr-bin` | Research needed | Binary |
| `proton-ge-custom-bin` | `GloriousEggroll/proton-ge-custom` | Extract to `~/.steam/compatibilitytools.d/` |
| `optiscaler-universal` | Research needed | Gaming upscaler binary |

**Script pattern for binary downloads:**

```bash
#!/bin/bash
# download-binary.sh <repo> <binary-name> <install-path>
REPO=$1; BIN=$2; DEST=${3:-/usr/local/bin}
LATEST=$(curl -sL "https://api.github.com/repos/${REPO}/releases/latest" | jq -r .tag_name)
curl -sLo "/tmp/${BIN}" "https://github.com/${REPO}/releases/download/${LATEST}/${BIN}-linux-amd64"
chmod +x "/tmp/${BIN}"
install -m 755 "/tmp/${BIN}" "${DEST}/${BIN}"
```

---

## 10. Source Builds — C/C++ (8 packages)

| Package | Repo | Build System | Notes |
|---|---|---|---|
| `bucklespring` | `zevv/bucklespring` | make | Needs libpulse-devel, libxtst-devel |
| `dualsensectl` | `nowrep/dualsensectl` | meson | PS5 controller |
| `mpdas` | `hrkfdn/mpdas` | make | MPD scrobbler, needs libmpdclient-devel |
| `neo-matrix` | `st3w/neo` | cmake | Matrix rain effect |
| `newsraft` | `newsraft/newsraft` | make | Needs curses, libcurl |
| `pipemixer-git` | Research | make | PipeWire TUI mixer |
| `rofi-file-browser-extended-git` | `marvinkreis/rofi-file-browser-extended` | cmake | Rofi plugin |
| `hxd` | Research | make | Hex editor |

**Containerfile pattern:**

```dockerfile
RUN git clone --depth=1 https://github.com/zevv/bucklespring /tmp/bucklespring && \
    cd /tmp/bucklespring && make && install -m 755 buckle /usr/local/bin/ && \
    rm -rf /tmp/bucklespring
```

---

## 11. Source Builds — Fennel/Lua (1 package)

| Package | Strategy |
|---|---|
| `fennel` | `curl -sLo /usr/local/bin/fennel https://fennel-lang.org/downloads/fennel-1.5.1-x86_64` && `chmod +x` |

Single static binary available from fennel-lang.org.

---

## 12. Custom / Personal Packages — Manual Port (11 packages)

These are personal/custom AUR packages that need manual porting:

| Package | Type | Strategy |
|---|---|---|
| `albumdetails` | Custom script | Copy from Arch, install to `/usr/local/bin` |
| `richcolors` | Custom script | Copy from Arch, install to `/usr/local/bin` |
| `neg-pretty-printer` | Custom script | Copy from Arch, install to `/usr/local/bin` |
| `proxypilot` | Custom tool | Build from source PKGBUILD |
| `vicinae-bin` | Custom dmenu wrapper | Build from source PKGBUILD |
| `wl` | Custom Wayland tool | Build from source PKGBUILD |
| `taoup` | Shell script | `git clone https://github.com/globalcitizen/taoup && install` |
| `hermes-agent` | Custom agent | Build from source |
| `iosevka-neg-fonts` | Custom font build | Rebuild with `iosevka` build system or copy TTFs |
| `pixora-icons-git` | Icon theme | `git clone && make install` or copy to `/usr/share/icons/` |
| `oports-git` | Custom tool | Build from source |

---

## 13. Questionable / Research Needed (8 packages)

| Package | Notes | Action |
|---|---|---|
| `amdgpu-vulkan-switcher-git` | GPU driver switcher script — may not be needed on Fedora with mesa defaults | Likely skip |
| `gvfs-onedrive` | OneDrive GVFS backend — use `rclone mount` instead | Alternative: rclone |
| `gvfs-wsdd` | WSDD for GVFS — experimental on Arch too | Likely skip |
| `oyo` | Unclear what this is | Research |
| `tanin-git` | Unclear | Research |
| `tmmpr` | Unclear | Research |
| `ytsurf` | YouTube TUI browser? | Research |
| `quickshell` / `quickshell-overview-git` | Qt6 Wayland shell — heavy build | Source build if needed |

---

## 14. Gaming — Steam Proton (2 packages)

| Package | Strategy |
|---|---|
| `proton-ge-custom-bin` | User installs to `~/.steam/compatibilitytools.d/` — not an image concern |
| `proton-cachyos` | CachyOS Proton patches — use GE-Proton instead |

**Not suitable for Containerfile** — these go in `$HOME` via Steam or ProtonUp-Qt (Flatpak).

---

## 15. VPN / Proxy Tools (3 packages, beyond COPR above)

| Package | Strategy |
|---|---|
| `zapret2` | Source build: `git clone https://github.com/bol-van/zapret && make` |
| `flclashx-bin` | Download AppImage from GitHub releases |
| `v2rayn-bin` | Download Linux binary from `2dust/v2rayN` releases |

---

## 16. Wayland Desktop Tools (4 packages)

| Package | Strategy |
|---|---|
| `swayosd` | COPR `erikreider:SwayNotificationCenter` or cargo install |
| `tessen` | Shell script: `git clone https://github.com/ayushnix/tessen && make install` |
| `xdg-ninja` | Shell script: `git clone https://github.com/b3nj5m1n/xdg-ninja && install` |
| `otter-launcher` | Source build from Git (Rust): `cargo install --git` |

---

## 17. Accept as Unavailable / Low Priority (4 packages)

| Package | Reason |
|---|---|
| `unarchiver` | Objective-C — use `unar` from `p7zip` or `patool` instead |
| `lib32-amdvlk-bin` | 32-bit AMDVLK — try `amdvlk.i686` or skip |
| `optiscaler-universal` | Windows gaming upscaler — may not work on Linux natively |
| `ollama-vulkan` | Standard `ollama` RPM already supports Vulkan via ROCm |

---

## Summary by Strategy

| Strategy | Count | Packages |
|---|---|---|
| Skip (Arch-specific) | 12 | base, base-devel, linux, linux-headers, etc. |
| Already in Fedora RPMs | 8 | dcfldd, nethack, rmlint, swappy, etc. |
| Google Chrome repo | 1 | google-chrome |
| COPR repos | 10 | v2raya, amneziawg, sing-box, cosmic-greeter, etc. |
| npm | 2 | claude-code, instagram-cli |
| pipx | 6 | cmake-language-server, dool, epr, mpdris2, etc. |
| cargo install | 8 | amdgpu_top, lutgen, rustmission, satty, etc. |
| go install | 5 | ssh-to-age, scc, massren, unflac, gowall |
| Binary downloads | 24 | aliae, carapace, freeze, hishtory, pup, etc. |
| Source builds (C/C++) | 8 | bucklespring, dualsensectl, mpdas, etc. |
| Static binary (fennel) | 1 | fennel |
| Custom/personal ports | 11 | albumdetails, richcolors, proxypilot, etc. |
| Research needed | 8 | oyo, tanin, tmmpr, ytsurf, etc. |
| Steam/user-space | 2 | proton-ge-custom, proton-cachyos |
| VPN/proxy source | 3 | zapret2, flclashx, v2rayn |
| Wayland tools | 4 | swayosd, tessen, xdg-ninja, otter-launcher |
| Accept unavailable | 4 | unarchiver, lib32-amdvlk, optiscaler, ollama-vulkan |
| **Total** | **107** | |

---

## Priority Order for Implementation

1. **Fedora RPMs** (8) — immediate, just fix mapping
2. **Google Chrome repo** (1) — one-liner
3. **COPR repos** (10) — add repo + install
4. **Binary downloads** (24) — scriptable, write `download-binaries.sh`
5. **cargo/go/pip/npm** (21) — extend existing Containerfile sections
6. **Source builds** (9) — write build scripts per package
7. **Custom ports** (11) — manual work, do last
8. **Skip/unavailable** (16+) — document and move on
