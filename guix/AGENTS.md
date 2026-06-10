# Guix System Migration — Agent Instructions

Auto-generated agent guide for migrating neg's Arch/CachyOS workstation to GNU Guix System.
Last updated: 2026-05-17

---

## 1. Environment Overview

### VM Access
```bash
# SSH (key auth, host key already trusted)
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    -i ~/.ssh/id_ed25519 -p 10023 guest@localhost

# Serial console (if SSH is down)
ssh ... guest@localhost 'sudo virsh console guix --force'
# or: ./guix/vm.sh console

# VM management
./guix/vm.sh start|stop|ssh|console|status
```

### VM Specs
| Resource | Value |
|----------|-------|
| CPUs | 12 vCPU (host-passthrough) |
| RAM | 8 GB |
| Disk | 300 GB (thin-provisioned qcow2, 26G used) |
| Boot | UEFI (OVMF) |
| Network | QEMU user-mode NAT, guest gets 10.0.2.15/24 |
| SSH port | guest:2222 → host:10023 |

### Key Paths
| What | Where |
|------|-------|
| VM image | `/var/lib/libvirt/images/guix-system-vm-1.5.0.qcow2` |
| Libvirt XML | `/tmp/guix-vm.xml` |
| System config | `/etc/config.scm` (inside VM) |
| Custom channel (host) | `/home/neg/src/cfg/guix/channel/` |
| vm.sh script | `/home/neg/src/cfg/guix/vm.sh` |

### Guix Daemon
```
--cores=32 --max-jobs=4
--substitute-urls=https://bordeaux.guix.gnu.org
50 build users (guixbuilder01-50)
```
**Important:** `ci.guix.gnu.org` is BLOCKED from Russia. Use ONLY `bordeaux.guix.gnu.org`.

### SSH Security
- User: `guest`, password: `guix` (serial console only)
- SSH: key auth (`~/.ssh/id_ed25519`)
- sudo: passwordless for guest (`%wheel ALL=NOPASSWD: ALL`)

---

## 2. Packages Already Installed

### In System Config (`/etc/config.scm` packages field)
```
zsh git neovim tmux bat fd ripgrep btop htop rsync btrfs-progs smartmontools curl wget
python python-pip rust rust:cargo node make gcc-toolchain expect socat nmap iperf lsof
strace tree jq tealdeer direnv difftastic just shellcheck pandoc graphviz git-lfs zoxide mpv
abduco age alsa-utils aria2 atop chezmoi cowsay cpio dash dnsmasq dosfstools efibootmgr
entr eza fastfetch fclones figlet fio fping git-crypt git-delta git-extras helix hexyl
hyperfine hwinfo iftop inotify-tools iwd jpegoptim jujutsu less lolcat lvm2 mandoc mediainfo
miller minicom mtr nano ncdu patchelf pigz playerctl pngquant powertop pre-commit progress
pv pwgen scc shfmt sops sox sshfs stress-ng tcpdump toilet traceroute ugrep unbound uv vale
valgrind vim vnstat watchexec whois xfsprogs python-yamllint zathura rclone borg hashcat
beets mpd mpc neomutt wl-clipboard wlogout wlr-randr wofi wtype
```

### In User Profile (`guix package -I`)
```
+ hyprland hyprlock hypridle hyprpicker
+ chromium (ungoogled-chromium-wayland) icecat
+ kate ark konsole
+ alacritty foot wezterm
+ go (installed with --without-tests=go)
+ podman
```

### Nonguix Channel (proprietary)
- Added to `/etc/guix/channels.scm` (needs `guix pull` after adding)
- Available: steam, amdgpu-firmware, google-chrome-stable

---

## 3. Packages That FAILED and Why

| Package | Reason | Fix |
|---------|--------|-----|
| **github-cli** | `go-github-com-tetratelabs-wazero` test fails | Needs custom package with `#:tests? #f` for wazero dep |
| **kitty** | `go-1.26.2` + multiple Go lib tests fail | Needs custom package with `#:tests? #f` for go + Go deps |
| **go** (system) | Tests fail during build | Works in profile with `guix install go --without-tests=go` |
| **limine** | Not in Guix or nonguix | Needs full packaging from source |

---

## 4. How to Port an AUR Package to Guix

### Step 1: Get package info
```bash
# On host: get AUR package details
pacman -Qi <package-name> 2>/dev/null | grep -E "^Name|^Version|^URL|^Depends"
```

### Step 2: Decide approach

**Option A — Already in Guix:**
```bash
guix search "^<name>$" | grep "^name:"
# If found: guix install <name>
```

**Option B — Pre-built binary (-bin package):**
```bash
# Download the release binary, check hash
wget <release-url>
sha256sum <file>

# Use template: guix/channel/custom/packages/binaries.scm
# Fill in: name, version, url, hash
```

**Option C — From source (Rust/Go/C):**
```bash
# Generate package definition
guix import crate <name>          # for Rust
guix import go <import-path>      # for Go
guix import pypi <name>           # for Python

# Or manual with git-fetch
```

### Step 3: Create package definition
```scheme
;; guix/channel/custom/packages/<name>.scm
(define-module (custom packages <name>)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module (guix build-system ...)
  #:use-module (guix licenses))

(define-public <name>
  (package
    (name "<name>")
    (version "<version>")
    (source (origin
              (method git-fetch)
              (uri (git-reference
                    (url "<repo-url>")
                    (commit "<tag-or-commit>")))
              (file-name (git-file-name name version))
              (sha256 (base32 "<fill-after-first-build>"))))
    (build-system ...)
    (inputs (list ...))
    (home-page "<url>")
    (synopsis "...")
    (description "...")
    (license ...)))
```

### Step 4: Build and test
```bash
# From inside VM:
cd /path/to/channel
guix build -f custom/packages/<name>.scm
# On first build it fails with hash — copy the expected hash from error message
# Then update the sha256 field and rebuild
guix build -f custom/packages/<name>.scm  # should succeed
guix package -f custom/packages/<name>.scm  # install
```

### Step 5: Add to system config (optional)
Add to `/etc/config.scm` packages list, then:
```bash
sudo guix system reconfigure /etc/config.scm
```

---

## 5. How to Create a Shepherd Service

### Template
```scheme
;; guix/channel/custom/services/<name>.scm
(define-module (custom services <name>)
  #:use-module (gnu services shepherd)
  #:use-module (guix gexp))

(define <name>-shepherd-service
  (shepherd-service
    (provision '(<name>))
    (requirement '(networking))           ; or: user-processes
    (start #~(make-forkexec-constructor
              (list #$(file-append <package> "/bin/<binary>")
                    "<flag1>" "<flag2>")
              #:log-file "/var/log/<name>.log"))
    (stop #~(make-kill-destructor))
    (auto-start? #t)))                    ; or #f for manual start
```

### Adding to system config
In `/etc/config.scm`, add to `(services ...)`:
```scheme
(simple-service '<name>-shepherd
                shepherd-root-service-type
                (list <name>-shepherd-service))
```

Alternatively, for services already in Guix:
```scheme
(service tailscaled-service-type)         ; if exists in (gnu services vpn)
(service mpd-service-type)                ; if exists in (gnu services audio)
```

---

## 6. Custom Channel Setup

### Structure
```
guix/channel/
├── .guix-channel            # (channel (version 0) (directory "custom"))
└── custom/
    ├── packages/
    │   ├── binaries.scm     # template for pre-built binary packages
    │   ├── kanata.scm       # kanata keyboard remapper (Rust, WIP)
    │   └── vicinae.scm      # vicinae launcher (WIP)
    └── services/
        ├── mpd.scm          # MPD Shepherd service
        └── tailscale.scm    # Tailscale Shepherd service
```

### Adding to VM
```bash
# Method 1: Git push from host, pull in VM
# Method 2: scp the channel directory
# Method 3: Add as local channel in /etc/guix/channels.scm

# Example channels.scm addition:
(cons (channel
        (name 'custom)
        (url "file:///path/to/channel"))
      %default-channels)
```

---

## 7. AUR Packages Needing Porting

### Priority 1 — Used Daily
| Package | Type | URL |
|---------|------|-----|
| vicinae-bin | Qt6 launcher | https://github.com/vicinaehq/vicinae |
| kanata-bin | Keyboard remapper (Rust) | https://github.com/jtroo/kanata |
| zapret2 | DPI bypass | https://github.com/bol-van/zapret2 |
| proxypilot | Proxy tool | https://github.com/Finesssee/ProxyPilot |
| zen-browser-bin | Browser | zen-browser (nonguix?) |

### Priority 2 — Networking/VPN
| Package | Type | URL |
|---------|------|-----|
| sing-box-bin | VPN/proxy | https://github.com/SagerNet/sing-box |
| v2raya-bin | V2Ray frontend | https://github.com/v2rayA/v2rayA |
| tailray | Tailscale tray | https://github.com/NotAShelf/tailray |

### Priority 3 — Utilities
| Package | Type | URL |
|---------|------|-----|
| oports-git | Port scanner | https://github.com/sdushantha/oports |
| antigravity-tools-bin | System tools | https://github.com/lbjlaq/Antigravity-Manager |
| throne | App launcher | https://throneproj.github.io |
| witr-bin | WiFi tool | https://github.com/pranshuparmar/witr |

### Priority 4 — Gaming
| Package | Type | URL |
|---------|------|-----|
| proton-ge-custom-bin | Proton GE | https://github.com/GloriousEggroll/proton-ge-custom |
| protontricks | Wine helper | https://github.com/Matoking/protontricks |
| protonup-rs-bin | Proton updater | https://github.com/AUNaseef/protonup-rs |
| mangohud | Overlay | https://github.com/flightlessmango/MangoHud |

---

## 8. Services to Port

| systemd Service | Shepherd Equivalent | Notes |
|----------------|-------------------|-------|
| tailscaled | custom/services/tailscale.scm (template done) | Needs tailscale package |
| ollama | Needs custom service | GPU passthrough needed for real use |
| mpd | custom/services/mpd.scm (template done) | Config at ~/.config/mpd/mpd.conf |
| syncthing | `(service syncthing-service-type)` | Already in Guix |
| transmission | `(service transmission-daemon-service-type)` | Already in Guix |
| unbound | `(service unbound-service-type)` | Already in Guix |
| iwd | `(service iwd-service-type)` | Already in Guix |
| dnsmasq | `(service dnsmasq-service-type)` | Already in Guix |

---

## 9. Common Operations Cheat Sheet

```bash
# Enter VM
./guix/vm.sh ssh

# Install package
guix install <name>

# Search package
guix search <name>

# Build package from local .scm file
guix build -f path/to/package.scm

# Install from local .scm
guix package -f path/to/package.scm

# Reconfigure system
sudo guix system reconfigure /etc/config.scm && sudo reboot --kexec

# Check build log
sudo zcat /var/log/guix/drvs/XX/XXXXX-*.drv.gz

# Add build users (if exhausted)
sudo useradd -r -g guixbuild -G guixbuild,kvm -s /sbin/nologin \
  -d /var/empty guixbuilderXX

# Check substitute availability
guix build <name> --dry-run

# Build with fallback if substitute fails
guix install <name> --fallback

# Skip tests for a package
guix install <name> --without-tests=<name>
```

---

## 10. Parallel Work Strategy with Sub-Agents

For maximum throughput, spawn multiple sub-agents in parallel:

```text
Sub-agent 1: "Port AUR packages from guix/AGENTS.md section 7 to Guix packages"
Sub-agent 2: "Port systemd services from guix/AGENTS.md section 8 to Shepherd"  
Sub-agent 3: "Configure Guix Home for Hyprland dotfiles"
Sub-agent 4: "Test and install packages in VM via SSH"
```

Each sub-agent:
- Reads this AGENTS.md for context
- Works on its assigned section independently
- Outputs completed package/service files to the channel directory
- Can SSH into the VM to test: `ssh -p 10023 guest@localhost -i ~/.ssh/id_ed25519`

---

## 11. Known Issues & Workarounds

| Issue | Workaround |
|-------|-----------|
| `ci.guix.gnu.org` blocked from Russia | Use only `bordeaux.guix.gnu.org` |
| Go package tests fail | Use `guix install <pkg> --without-tests=go` or set `#:tests? #f` in package definition |
| Build users exhausted | Add more: `sudo useradd -r -g guixbuild ... guixbuilderXX` |
| Profile locked | `sudo rm -f /var/guix/profiles/per-user/guest/.guix-profile.lock` |
| Substitute download EOF | Retry with `--fallback` flag |
| VM IO error (tmpfs full) | Image MUST be on real disk, not /tmp |
| VM paused | `sudo virsh resume guix` |
| SSH timeout | VM overloaded with builds, wait and retry |
