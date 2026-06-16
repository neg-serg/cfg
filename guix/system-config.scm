;; ── Minimal Guix config for VM image build ──
;; Full package list via specifications->packages + custom channel
(use-modules (gnu) (guix) (srfi srfi-1))

(use-service-modules desktop networking ssh xorg spice shepherd sddm dns
                      cups virtualization)
(use-package-modules admin audio base bootloaders compression
                      curl disk file fonts gnupg linux networking
                      package-management rsync ssh
                      version-control vim wget xdisorg xorg)
;; Explicit: mpd from audio, zsh from shells (avoid shadowing)
(use-modules (gnu packages mpd)
             ((gnu packages shells) #:select (zsh)))

;; Custom channel imports
(use-modules (custom packages all)
             (custom packages mpdas)
             (custom packages powerlevel10k))

(define vm-image-motd (plain-file "motd" "
\x1b[1;37mGuix Migration Evaluation VM\x1b[0m

Hyprland + greetd — log in as 'neg' (no password)
Deploy: sudo -i guix system reconfigure /etc/config.scm -L ~/cfg-channel
Services: herd start mpd|tailscaled|ollama

\x1b[1;33mEvaluating Arch/CachyOS to Guix System migration.\x1b[0m
"))

;; Shepherd services disabled for initial build

(operating-system
  (host-name "guix-eval")
  (timezone "Europe/Moscow")
  (locale "en_US.utf8")

  (keyboard-layout
    (keyboard-layout "us,ru"
                     #:options '("grp:alt_shift_toggle")))

  (label (string-append "GNU Guix "
           (or (getenv "GUIX_DISPLAYED_VERSION")
               (package-version guix))))

  (firmware '())

  (bootloader (bootloader-configuration
    (bootloader grub-bootloader)
    (targets '("/dev/vda"))
    (terminal-outputs '(console))))

  (file-systems (cons (file-system
    (mount-point "/")
    (device (file-system-label "Guix_image"))
    (type "ext4"))
    %base-file-systems))

  (users (cons* (user-account
    (name "guixbuilder11") (group "guixbuild")
    (supplementary-groups '("guixbuild" "kvm"))
    (comment "Guix Build User 11")
    (home-directory "/var/empty")
    (shell "/run/current-system/profile/sbin/nologin"))
    (user-account
    (name "guixbuilder12") (group "guixbuild")
    (supplementary-groups '("guixbuild" "kvm"))
    (comment "Guix Build User 12")
    (home-directory "/var/empty")
    (shell "/run/current-system/profile/sbin/nologin"))
    (user-account
    (name "guixbuilder13") (group "guixbuild")
    (supplementary-groups '("guixbuild" "kvm"))
    (comment "Guix Build User 13")
    (home-directory "/var/empty")
    (shell "/run/current-system/profile/sbin/nologin"))
    (user-account
    (name "guixbuilder14") (group "guixbuild")
    (supplementary-groups '("guixbuild" "kvm"))
    (comment "Guix Build User 14")
    (home-directory "/var/empty")
    (shell "/run/current-system/profile/sbin/nologin"))
    (user-account
    (name "neg") (comment "neg")
    (password (crypt "neg" "$6$rounds=4096"))
    (group "users")
    (supplementary-groups '("wheel" "netdev" "audio" "video" "kvm" "input" "dialout"))
    (shell (file-append zsh "/bin/zsh")))
    (user-account
    (name "xen") (comment "VR Session")
    (password "") (group "users")
    (uid 1100)
    (supplementary-groups '("wheel" "audio" "video" "input"))
    (home-directory "/home/xen")
    (shell (file-append zsh "/bin/zsh")))
    %base-user-accounts))

  (sudoers-file (plain-file "sudoers" "\
root ALL=(ALL) ALL
%wheel ALL=NOPASSWD: ALL\n"))

  (pam-services
    (base-pam-services #:allow-empty-passwords? #t))

  (packages
    (append
      (specifications->packages
        (list
          ;; ── Shell & Terminal ──
          "zsh" "git" "neovim" "tmux" "bat" "fd" "ripgrep"
          "eza" "fzf" "zoxide" "direnv" "abduco" "dash"
          "fastfetch" "cowsay" "figlet" "toilet" "lolcat"
          "chafa" "viu"

           ;; ── System Monitoring ──
           "btop" "htop" "atop" "bottom" "iotop" "powertop"
           "ncdu" "dust" "duf" "progress" "pv"
           "strace" "lsof" "sysstat" "cpupower"
           "hwinfo" "lshw" "inxi" "smartmontools"
           "bpftrace" "perf"
           "fio" "memtester" "turbostat" "schedtool" "plocate"
           "lm-sensors" "inotify-tools" "hw-probe"

           ;; ── Network & Connectivity ──
           "curl" "wget" "wget2" "aria2"
           "rsync" "rclone" "syncthing"
           "openssh" "sshfs" "sshpass" "socat"
           "nmap" "tcpdump" "traceroute" "fping" "mtr"
           "iwd" "dnsmasq" "unbound" "dhcpcd"
           "nethogs" "bandwhich" "iftop" "vnstat" "iperf"
           "network-manager" "network-manager-applet"
           ;; tailscale provided by custom channel, not main Guix
           "wireguard-tools"
           "doggo" "whois"
           "avahi" "nss-mdns"
           "bluez" "bluez-utils"
           "firewalld" "ufw"
           "samba" "openbsd-netcat" "iperf3"
           "httpie" "xh" "curlie"

          ;; ── Development ──
          "python" "python-pip" "python-pipx" "python-poetry"
          "python-pyperclip" "python-textual" "python-mutagen"
          "python-faker" "python-internetarchive" "python-telethon"
          "python-ascii-magic" "python-rapidgzip"
          "rust" "rust:cargo" "go" "node" "ruby"
          "make" "gcc-toolchain" "expect" "patchelf"
          "cmake" "meson" "ninja" "pkg-config"
          "gdb" "lldb" "valgrind"
          "openblas" "fennel" "lua" "lua-language-server"
          "sbcl" "supercollider" "sc3-plugins"
          "shellcheck" "shfmt" "ruff" "uv" "vale"
          "yamllint" "taplo" "pre-commit"
          "difftastic" "just" "scc"
           "tree-sitter"
           "clang" "npm" "python-numpy" "python-orjson"
           "lua-5.3" "perl-image-exiftool" "gallery-dl"

           ;; ── Git / VCS ──
          "git-lfs" "git-crypt" "git-delta" "git-extras"
          "git-filter-repo" "gh" "glow" "tig" "lazygit"
           "jujutsu" "subversion" "gitleaks" "onefetch"
           "gist"

           ;; ── Editors ──
          "vim" "nano" "helix" "kate"

          ;; ── Terminal Emulators ──
          "alacritty" "foot" "kitty" "ghostty"
          "zellij" "wezterm"

          ;; ── File Managers ──
          "yazi" "broot" "pcmanfm" "nautilus"
          "tree" "erdtree" "fclones"

          ;; ── Wayland / Compositor ──
          "hyprland" "hyprlock" "hypridle" "hyprpicker"
          "wl-clipboard" "wlr-randr" "wlogout" "wtype" "wofi"
          "slurp" "grim" "swappy" "satty"
          "swayimg" "swayosd" "swaybg"
          "dunst" "mako" "waybar"
          "cliphist" "wf-recorder" "wayvnc" "waypipe"
          "wev" "ydotool"
          "xdg-desktop-portal-hyprland" "xdg-user-dirs-gtk"
           "uwsm"
           "hyprpolkitagent" "qt5-wayland" "qt6-wayland"

           ;; ── Desktop / GNOME ──
          "gnome-backgrounds" "gnome-calculator" "gnome-calendar"
          "gnome-characters" "gnome-clocks"
          "gnome-color-manager" "gnome-connections" "gnome-console"
          "gnome-contacts" "gnome-control-center"
          "gnome-disk-utility" "gnome-font-viewer"
          "gnome-keyring" "gnome-logs" "gnome-maps"
          "gnome-music" "gnome-remote-desktop"
          "gnome-session" "gnome-settings-daemon"
          "gnome-shell" "gnome-software"
          "gnome-system-monitor" "gnome-text-editor"
          "gnome-tweaks" "gnome-weather"
          "simple-scan" "sushi" "yelp" "epiphany"
           "orca" "papers"
           "gnome-menus" "gnome-tour" "gnome-user-docs" "gnome-user-share"
           "gvfs" "rygel" "tumbler" "snapshot" "loupe"
           "greetd" "tuigreet"

          ;; ── Browsers ──
          "icecat" "ungoogled-chromium-wayland"
          ;; nonguix: "google-chrome-stable"

          ;; ── Media & Audio ──
          "mpv" "ffmpeg" "ffmpegthumbnailer"
          "imagemagick" "graphviz"
          "mpd" "mpc" "beets" "picard"
          "cava" "carla" "qpwgraph" "easyeffects"
          "sox" "id3v2" "mediainfo" "chromaprint"
          "playerctl" "wireplumber" "pavucontrol"
          "gstreamer" "gst-plugins-base" "gst-plugins-good"
           "gst-plugins-bad" "gst-plugins-ugly" "gst-libav"
           "sonic-visualiser" "helvum" "lsp-plugins" "grilo-plugins"

           ;; ── Graphics & Images ──
          "gimp" "blender" "inkscape"
          "jpegoptim" "optipng" "pngquant" "scour"
          "resvg" "chafa" "viu"
          "rawtherapee" "darktable"

          ;; ── Documents & PDF ──
          "zathura" "zathura-pdf-poppler"
          "pandoc" "texlive-base"
          "lowdown" "mandoc"

          ;; ── Archive & Compression ──
          "pigz" "pbzip2" "lbzip2" "ouch" "unzip" "zip"
          "cpio" "p7zip" "unarchiver" "patool"
          "dos2unix" "convmv"

          ;; ── Storage & Filesystems ──
          "btrfs-progs" "dosfstools" "xfsprogs"
          "lvm2" "gptfdisk" "efibootmgr"
          "ddrescue" "testdisk"

          ;; ── Virtualization ──
          "qemu" "libvirt" "virt-manager" "virt-viewer"
          "podman" "docker" "distrobox" "nerdctl"
          "skopeo" "slirp4netns" "dive"

          ;; ── Security & Encryption ──
          "age" "age-plugin-yubikey" "yubikey-manager"
          "gopass" "password-store" "hashcat"
          "sops" "gnupg"
          "sbctl"

          ;; ── Gaming ──
          "nethack" "dosbox"
          "mangohud" "gamescope" "gamemode"
          ;; nonguix: "steam" "wine" "lutris" "protonup-qt"

          ;; ── Email & Productivity ──
          "neomutt" "himalaya" "isync" "vdirsyncer"
          "urlscan" "urlwatch" "recoll"

          ;; ── Communication ──
          "telegram-desktop" "localsend"

          ;; ── Misc Tools ──
          "jq" "yq" "jc" "miller"
          "hyperfine" "entr" "moreutils"
          "rlwrap" "reptyr" "expect" "parallel"
          "ripgrep" "ugrep" "fd" "choose"
          "hexyl" "diff-so-fancy" "sad"
          "tealdeer" "tldr"
          "asciinema" "screenfetch"
          "android-tools"
           "fonts-jetbrains-mono"
           "chezmoi" "pwgen" "cdparanoia" "enca" "iotop-c"
           "wireshark-cli" "zbar" "zk" "zmap" "w3m"
           "geoip" "hunspell-dict-ru" "libpulse" "pass" "hxd"
           "openocd" "libnotify" "xdg-utils"
           "jupyterlab" "multipath-tools" "pastel"
           "stress-ng" "parted" "which" "sudo" "less" "man-pages"
           "elfutils" "kexec-tools" "tree-sitter-cli"
           "qrencode" "goaccess" "htmlq"
           "bucklespring" "amneziawg-tools"
           "i3-wm" "i3status" "networkmanager" "nm-connection-editor"
           "goimapnotify" "gitogue" "wiremix"
           "transmission-cli" "television" "showtime" "rmpc"
           "rofi" "pipewire" "neg-pretty-printer" "prettyping"
           "plasma-wayland-session" "kvantum-qt5"

           ;; ── Display Manager / Login ──
           "greetd" "tuigreet"

           ;; ── Printing ──
           "cups" "system-config-printer"
           "cups-pk-helper"

           ;; ── Other ──
          "etckeeper" "borg" "rclone"
          "grafana" "unbound"
           "streamlink" "yt-dlp"
           "nicotine+" "transmission"
           "minicom" "ttyd"
          "freerdp" "remmina"
          "fwupd" "udiskie" "upower"
           "cage" "xwaylandvideobridge"
           "kvantum" "qt5ct" "qt6ct" "plasma-desktop" "plasma-workspace"
           "polkit-kde-agent" "breeze" "breeze-icons"
           "corectrl" "openrgb"

           ;; ── KDE Apps ──
          "ark" "konsole" "kate"

           ;; ── Custom channel packages ──
           ;; Added via all-custom-packages from (custom packages all)
           ;; plus mpdas, powerlevel10k from their respective modules
           )
       ;; all-custom-packages        ;; disabled — module loading broken
       (list mpdas powerlevel10k) ;; additional custom packages
      %base-packages)))

  (services
    (cons* (service openssh-service-type
        (openssh-configuration
          (port-number 2222)
          (password-authentication? #t)))
      (service dhcpcd-service-type)
      (service unbound-service-type)
      (service spice-vdagent-service-type)
      ;; greetd display manager
      (simple-service 'greetd
        shepherd-root-service-type
        (list (shepherd-service
                (provision '(greetd))
                (requirement '(user-processes))
                (start #~(make-forkexec-constructor
                          (list #$(file-append greetd "/bin/greetd")
                                "-c" "/etc/greetd/config.toml")
                          #:log-file "/var/log/greetd.log"))
                (stop #~(make-kill-destructor))
                (auto-start? #t))))
      ;; Shepherd services — disabled for initial build
      ;; (simple-service 'mpd-shepherd ...)
      ;; (simple-service 'tailscale-shepherd ...)
      ;; (simple-service 'ollama-shepherd ...)
      ;; (simple-service 'kanata-shepherd ...)
      ;; (simple-service 'mpdas-shepherd ...)
      %desktop-services))

  (name-service-switch %mdns-host-lookup-nss)))
