(use-modules (gnu) (guix))
(use-service-modules networking ssh desktop)
(use-package-modules base ssh shells certs admin)
(use-modules (custom packages all))

(operating-system
  (kernel (specification->package "linux"))
  (host-name "guix")
  (timezone "Europe/Moscow")
  (locale "en_US.utf8")
  (keyboard-layout (keyboard-layout "us,ru" #:options '("grp:alt_shift_toggle")))
  (bootloader (bootloader-configuration
    (bootloader grub-efi-bootloader)
    (targets '("/boot/efi"))
    (keyboard-layout keyboard-layout)))
  (file-systems (cons* (file-system
                         (mount-point "/boot/efi")
                         (device (uuid "3D2F-1F3A" 'fat32))
                         (type "vfat"))
                       (file-system
                         (mount-point "/")
                         (device (uuid "9cefda31-a98c-47c7-bfd8-dbeb35e66965" 'xfs))
                         (type "xfs")
                          (options ""))
                       %base-file-systems))
  (users (cons (user-account
    (name "neg")
    (group "users")
    (supplementary-groups '("wheel" "netdev" "audio" "video" "kvm" "input"))
    (password (crypt "change-me-on-first-login" "$6$riy.KguvT7QpDgWi"))
    (shell (file-append zsh "/bin/zsh")))
    %base-user-accounts))
  (sudoers-file (plain-file "sudoers" "root ALL=(ALL) ALL\n%wheel ALL=NOPASSWD: ALL\n"))
  (firmware (list (specification->package "amdgpu-firmware")
                    (specification->package "radeon-firmware")
                    (specification->package "linux-firmware")
                    (specification->package "amd-microcode")))
  (kernel-arguments
    (list "modprobe.blacklist=usbmouse,usbkbd" "quiet"
          "zswap.enabled=0" "nowatchdog" "amd_iommu=on" "video=3840x2160@240"))
  
  (packages (append
    (map specification->package
      '("zsh" "git" "neovim" "tmux" "bat" "fd" "ripgrep" "eza" "fzf" "zoxide" "direnv"
        "btop" "htop" "fastfetch" "curl" "wget" "aria2" "openssh" "rsync"
        "python" "node" "rust" "go" "make" "gcc-toolchain" "cmake" "meson" "ninja"
        "gdb" "valgrind" "clang" "lldb" "jq" "yq" "tig" "chezmoi"
        "git-crypt" "git-lfs" "hyperfine" "difftastic" "just" "tealdeer" "hexyl"
        "shellcheck" "shfmt" "vale" "nmap" "tcpdump" "mtr" "socat" "strace" "lsof"
        "ncdu" "hwinfo" "smartmontools" "fio" "progress" "pv" "rclone" "restic"
        "yt-dlp" "streamlink" "tree" "ripgrep" "ugrep" "fd" "nethogs" "iftop" "vnstat"
        "mpv" "ffmpeg" "imagemagick" "gimp" "inkscape" "blender"
        "podman" "docker" "distrobox" "skopeo" "dive" "telegram-desktop" "obs"
        "beets" "difftastic" "jujutsu" "wireguard-tools" "powertop" "ranger" "notmuch"
        "hyprland" "kitty" "alacritty" "foot" "wezterm" "wlogout"
        "dunst" "slurp" "grim" "swappy" "swaybg" "swayimg" "wl-clipboard" "cliphist"
        "wf-recorder" "playerctl" "wireplumber" "pavucontrol" "neomutt" "isync"
        "vdirsyncer" "zathura" "zathura-pdf-poppler" "pandoc" "borg" "age" "pwgen"
        "qrencode" "syncthing" "cowsay" "figlet" "lolcat" "greetd" "tuigreet"
        "ark" "kate" "konsole" "breeze" "breeze-icons" "gnome-shell" "gdm"
        "gnome-control-center" "easyeffects" "carla" "helvum" "abduco" "atop"
        "bottom" "dash" "ddrescue" "diff-so-fancy" "entr" "expect" "fclones"
        "efibootmgr" "cpupower" "turbostat" "lvm2" "xfsprogs" "moreutils" "nethack"
        "picard" "plocate" "rlwrap" "sbcl" "sox" "subversion" "traceroute" "udiskie"
        "nss-certs" "font-jetbrains-mono" "font-fira-code" "font-google-noto" "font-dejavu" "qt5ct" "qt6ct"
        "network-manager" "bluez" "steam" "firefox"
        ))
    all-custom-packages
    %base-packages))
  (services (append (list (service greetd-service-type)
                          (service openssh-service-type
                            (openssh-configuration (port-number 22) (password-authentication? #t))))
                    %desktop-services)))
