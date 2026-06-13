;; Production VM config — full toolset for neg's workstation
(use-modules (gnu) (guix) (srfi srfi-1))
(use-service-modules desktop networking ssh xorg spice shepherd)
(use-package-modules admin audio base bootloaders certs compression
 curl disk file fonts gnupg linux mpd networking
 package-management rsync ssh shells
 version-control vim wget xdisorg xorg)
(use-modules ((gnu packages shells) #:select (zsh)))
(operating-system
 (host-name "guix-eval")
 (timezone "Europe/Moscow")
 (locale "en_US.utf8")
 (keyboard-layout
 (keyboard-layout "us,ru"
 #:options '("grp:alt_shift_toggle")))
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
 (name "neg") (comment "neg")
 (password (crypt "neg"
 "$6$rounds=4096$SxT0QXvizdX0biWn"))
 (group "users")
 (supplementary-groups '("wheel" "netdev" "audio" "video" "kvm" "input"))
 (shell (file-append zsh "/bin/zsh")))
 %base-user-accounts))
 (sudoers-file (plain-file "sudoers" "\
root ALL=(ALL) ALL
%wheel ALL=NOPASSWD: ALL\n"))
 (packages
 (append
 (specifications->packages
 (list
 ;; Shell & Terminal
 "zsh" "git" "neovim" "tmux" "bat" "fd" "ripgrep"
 "fzf" "zoxide" "direnv" "abduco" "dash"
 "cowsay" "figlet" "lolcat"
 "chafa" 
 ;; System Monitoring
 "btop" "htop" "atop" "iotop" "powertop"
 "ncdu" "progress" "pv"
 "strace" "lsof" "sysstat" "cpupower"
 "hwinfo" "lshw" "inxi" "smartmontools"
 "fio" "memtester" "plocate" "inotify-tools"
 ;; Network & Connectivity
 "curl" "wget" "wget2" "aria2"
 "rsync" "rclone" "syncthing"
 "openssh" "sshfs" "sshpass" "socat"
 "nmap" "tcpdump" "traceroute" "fping" "mtr"
 "dnsmasq" 
 "wireguard-tools" "whois"
 "avahi" "nss-mdns" 
 ;; Development
 "python" "python-pip"
 "rust" "go" "node" "ruby"
 "make" "gcc-toolchain" "expect" "patchelf"
 "cmake" "meson" "ninja" "pkg-config"
 "gdb" "valgrind"
 "fennel"
 "shellcheck" 
 "pre-commit"
 "tree-sitter"
 ;; Git / VCS
 "git-lfs" "git-crypt" 
 "tig" 
 "subversion" 
 ;; Editors & Terminals
 "vim" "nano" "kate"
 "alacritty" "foot" "kitty" 
 ;; File Managers
 "pcmanfm" "nautilus"
 "tree" 
 ;; Wayland / Compositor
 "wl-clipboard" "wlr-randr" "wlogout" "wtype" "wofi"
 "slurp" "grim" "swappy" 
 "swaybg"
 "dunst" "mako" "waybar"
 "wf-recorder" "waypipe"
 ;; Desktop / GNOME
 
 
 "simple-scan" "sushi" "yelp" "epiphany"
 "evince"
 "greetd" 
 ;; Browsers
 
 ;; Media & Audio
 "mpv" "ffmpeg" "ffmpegthumbnailer"
 "imagemagick" "graphviz"
 "mpd" "mpc" "beets" "picard"
 "cava" "carla" "qpwgraph" 
 "sox" "mediainfo" "chromaprint"
 "playerctl" "wireplumber" "pavucontrol"
 "gstreamer" "gst-plugins-base" "gst-plugins-good"
 "gst-plugins-bad" "gst-plugins-ugly" "gst-libav"
 "lsp-plugins"
 ;; Graphics & Images
 "gimp" "blender" "inkscape"
 "jpegoptim" "optipng" "pngquant" 
 "rawtherapee" "darktable"
 ;; Documents & PDF
 "zathura" "zathura-pdf-poppler"
 "pandoc" 
 ;; Archive & Compression
 "pigz" "pbzip2" "lbzip2" "unzip" "zip"
 "cpio" "7zip"
 ;; Storage & Filesystems
 "btrfs-progs" "dosfstools" "xfsprogs"
 "lvm2" "gptfdisk" "efibootmgr" "ddrescue" "testdisk"
 ;; Virtualization
 "qemu" "libvirt" "virt-manager" "virt-viewer"
 "podman" "docker" 
 "skopeo" "slirp4netns" 
 ;; Security
 "age" 
 "password-store" "hashcat" "gnupg"
 ;; Gaming
 "nethack" "dosbox"
 "mangohud" 
 ;; Email & Productivity
 "neomutt" "isync" "vdirsyncer"
 "urlscan" "recoll"
 ;; Communication
 "telegram-desktop"
 "transmission"
 ;; Misc Tools
 "jq" "jc" 
 "hyperfine" "entr" "moreutils"
 "rlwrap" "reptyr" "parallel"
 "hexyl" "diff-so-fancy"
 "tealdeer" 
 "asciinema" "screenfetch"
 ;; Printing
 "cups" "system-config-printer"
 ;; Other
 "borg" "rclone" 
 "streamlink" "yt-dlp"
 "minicom" 
 "freerdp" "remmina"
 "fwupd" "udiskie" "upower"
 "chezmoi" "pwgen" "parted" "sudo" "less" "which"
 "qrencode" "stress-ng"
 "libnotify" "xdg-utils"
 "i3-wm" "i3status" "ansible" "ardour" "audacity" "awscli" "baobab" "bash" "bottom" "calibre" "cliphist" "clipman" "corectrl" "darktable" "delta" "digikam" "distrobox" "doctl" "easyeffects" "evince" "eza" "fastfetch" "filelight" "filezilla" "fish" "flameshot" "gamemode" "glances" "gparted" "handbrake" "helm" "kdenlive" "keepassxc" "kodi" "lsd" "mariadb" "meld" "neofetch" "nginx" "openshot" "partitionmanager" "pavucontrol" "peek" "postgresql" "qbittorrent" "redis" "scribus" "smplayer" "sqlite" "starship" "strawberry" "swayidle" "swaylock" "vlc" "watchexec" "wireshark") "ark" "cage" "difftastic" "dive" "fclones" "helix" "hypridle" "hyprland" "hyprlock" "hyprpicker" "jujutsu" "konsole" "ncmpcpp" "nicotine+" "openvpn" "ouch" "restic" "wayvnc" "wev" "wezterm" "xdg-desktop-portal-hyprland" "xdg-user-dirs" "ydotool" "yq")
 %base-packages))
 (services
 (cons*
 (service openssh-service-type
 (openssh-configuration
 (port-number 22)
 (password-authentication? #t)))
 (modify-services (remove
 (lambda (svc)
 (memq (service-kind svc)
 (list gdm-service-type)))
 %desktop-services)
 (guix-service-type config =>
 (guix-configuration
 (inherit config)
 (guix (current-guix))
 (substitute-urls
 (list "https://mirror.yandex.ru/mirrors/guix/"
 "https://bordeaux.guix.gnu.org"))
 (extra-options
 (list "--cores=24" "--max-jobs=8"))))))))
