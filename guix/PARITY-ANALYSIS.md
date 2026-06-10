# Guix-NixOS Package Parity Analysis
# Generated: 2026-05-26
# Source: vms/nixos/modules/packages.nix → guix/system-config-minimal.scm

## Available in Guix (130 packages — ADDED to config)
dunst grim slurp swappy xdg-desktop-portal-hyprland yt-dlp swayimg
gnome-keyring gnome-system-monitor gnome-text-editor gnome-tweaks
nautilus gnome-control-center gnome-disk-utility xdg-utils yelp
clang cmake gdb fzf sqlite lldb meson ninja binutils pkg-config
autoconf automake libtool flex bison ruby subversion pipx
nethogs wireplumber pipewire pavucontrol ffmpeg ffmpegthumbnailer
imagemagick font-jetbrains-mono parted sysstat cups slirp4netns skopeo
age-plugin-yubikey avahi bpftrace cava ccid cdparanoia chafa
chromaprint cliphist convmv curlie ddrescue diff-so-fancy distrobox
dive enca freerdp fwupd goaccess gptfdisk gvfs htmlq httpie iotop
isync jc kexec-tools libnotify liquidctl lm-sensors lowdown lshw
lsp-plugins man-pages memtester moreutils multipath-tools nuspell
openocd openrgb optipng ouch parallel pastel pbzip2 pcmanfm pcsc-tools
pgcli picard plocate qemu qpwgraph qrencode rclone recoll reptyr
rlwrap sshpass sudo telegram-desktop tig toilet transmission
tree-sitter tumbler udiskie unzip upower urlscan vdirsyncer virt-manager
virt-viewer w3m waypipe wayvnc wev wf-recorder which ydotool zbar zk
i3status inxi orca dualsensectl gallery-dl hw-probe newsraft patool
ttfautohint wget2 wlogout du-dust yq python-scour

## NOT in Guix (58 packages — need custom channel or skip)
loupe satty yazi swayosd xdg-user-dirs-gtk
# Custom channel (already defined, hash/download issues):
#   tailscale ollama gopass gamemode
android-tools bandwhich yubikey-manager cpufetch ctop doggo
erdtree fortune genact geoip gh gitleaks ghostty glow
yq-go hunspell-dict-ru id3v2 ioping iperf3 kmon lazygit lnav
nerdctl nicotine-plus amdgpu_top onefetch prettyping resvg ruff sad
sbctl schedtool scour sops sonic-visualiser tabiew taplo tesseract
ttyd urlwatch viu wireshark-cli xh zellij zmap handlr-regex
papers uwsm wiremix act advancecomp claude-code cmake-language-server
dcfldd ddccontrol google-chrome jdupes localsend neovim-remote
oh-my-posh par unflac wlr-which-key xdg-ninja

## Already in config (not counted above)
zsh git neovim tmux bat fd ripgrep btop htop rsync curl wget python
node make expect go podman socat nmap iperf lsof mtr tcpdump traceroute
fping iwd dnsmasq strace tree jq less lvm2 xfsprogs dosfstools
efibootmgr cpio dash patchelf pigz pv progress tealdeer direnv
difftastic just shellcheck pandoc graphviz git-lfs git-crypt git-delta
git-extras zoxide mpv abduco age alsa-utils aria2 atop chezmoi cowsay
entr eza fastfetch fclones figlet fio helix hexyl hyperfine hwinfo iftop
inotify-tools jpegoptim jujutsu lolcat mandoc mediainfo miller minicom
nano ncdu neomutt pngquant powertop pre-commit pwgen scc shfmt sox sshfs
stress-ng toilet ugrep uv vale valgrind vim vnstat watchexec whois
python-yamllint zathura borg hashcat wl-clipboard wlogout wlr-randr
wofi wtype hyprland hyprlock hypridle hyprpicker kate ark konsole
alacritty foot kitty greetd tuigreet icecat ungoogled-chromium-wayland
mangohud syncthing btrfs-progs smartmontools unbound

## Distro-specific / intentional skips
gcc → already have gcc-toolchain
iperf3 → already have iperf
limine/linux/linux-firmware → kernel-level, not in userland
firewalld/networkmanager → skipped for VM (use dhcpcd)
wine/lutris/gamescope → gaming, skip for VM
gnome-* (full desktop) → Hyprland-only target
pamac/pacman-contrib → Arch-specific
cosmic-greeter → use greetd
