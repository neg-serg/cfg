;; /etc/config.scm — Guix Evaluation VM with SSH, services, and system-level configs
;; User dotfiles handled by chezmoi — this config only deploys what needs root.
;; One-command: sudo -i guix system reconfigure /etc/config.scm -L /home/neg/cfg-channel
;; Then: chezmoi apply (for dotfiles)

(use-modules (gnu) (guix) (srfi srfi-1))
(use-service-modules desktop networking ssh xorg spice shepherd dns sddm)
(use-package-modules admin audio base bootloaders compression
                      curl disk file fonts gnupg linux networking
                      package-management rsync ssh
                      version-control vim wget xdisorg xorg)
(use-modules ((gnu packages shells) #:select (zsh))
             (gnu packages mpd)
             (gnu services sddm)
             (gnu system setuid)
             (custom packages tailscale)
             (custom packages ollama)
             (custom packages gopass)
             (custom packages bulk-binaries)
             (custom packages parity-push)
             (custom packages source-ports)
             (custom packages source-ioping)
             (custom packages nicotine+)
             (custom packages wl)
             (custom packages hunspell-dict-ru)
             (custom packages source-misc)
             (custom packages ddccontrol)
             (custom packages par)
             (custom packages themix)
             (custom packages quickshell)
             (custom packages ambxst))

;; Shepherd services (system-level — not chezmoi)
(define mpd-shepherd-service
  (shepherd-service
    (provision '(mpd))
    (requirement '(user-processes networking))
    (start #~(make-forkexec-constructor
              (list #$(file-append mpd "/bin/mpd")
                    "--no-daemon" "/home/neg/.config/mpd/mpd.conf")
              #:log-file "/var/log/mpd.log"))
    (stop #~(make-kill-destructor))
    (auto-start? #t)))

(define tailscale-shepherd-service
  (shepherd-service
    (provision '(tailscaled))
    (requirement '(networking))
    (start #~(make-forkexec-constructor
              (list #$(file-append tailscale "/bin/tailscaled")
                    "--state=/var/lib/tailscale/tailscaled.state"
                    "--socket=/run/tailscale/tailscaled.sock" "--port=41641")
              #:log-file "/var/log/tailscaled.log"))
    (stop #~(make-kill-destructor))
    (auto-start? #f)))

(define ollama-shepherd-service
  (shepherd-service
    (provision '(ollama))
    (requirement '(networking))
    (start #~(make-forkexec-constructor
              (list #$(file-append ollama "/bin/ollama") "serve")
              #:log-file "/var/log/ollama.log"))
    (stop #~(make-kill-destructor))
    (auto-start? #f)))

(define vm-image-motd (plain-file "motd" "
\x1b[1;37mGuix Migration Evaluation VM\x1b[0m

First login:
  git clone https://github.com/neg-serg/cfg.git ~/cfg
  chezmoi init --source ~/cfg && chezmoi apply

System reconfigure:
  sudo -i guix system reconfigure ~/cfg/guix/system-config-minimal.scm -L ~/cfg/guix/channel

\x1b[1;33mGuix handles system (pkgs+services+system-configs), chezmoi handles dotfiles.\x1b[0m
"))

;; System-level configs (needs root — not chezmoi)
(define greetd-config
  (plain-file "greetd.toml" "\
[terminal]
vt = 1

[default_session]
command = \"Hyprland\"
user = \"neg\"
"))

(define mpd-config
  (plain-file "mpd.conf" "\
music_directory    \"/home/neg/music\"
playlist_directory \"~/.config/mpd/playlists\"
db_file            \"~/.config/mpd/database\"
log_file           \"syslog\"
pid_file           \"~/.config/mpd/pid\"
state_file         \"~/.config/mpd/state\"
sticker_file       \"~/.config/mpd/sticker.sql\"

auto_update             \"yes\"
bind_to_address         \"any\"
restore_paused          \"yes\"
follow_inside_symlinks  \"yes\"
replaygain              \"off\"
mixer_type              \"software\"
metadata_to_use         \"artist,album,title,track,name,genre,date,composer,performer,disc\"

audio_output {
  type \"pipewire\"
  name \"PipeWire Output\"
}
"))

;; Activation: deploys system-level configs on every reconfigure
;; User dotfiles (Hyprland, zsh, kanata, etc.) stay in chezmoi — run `chezmoi apply`
(define system-config-activation
  #~(begin
      (use-modules (guix build utils))
      ;; MPD config directory + file
      (let* ((home (passwd:dir (getpw "neg")))
             (mpd-dir (string-append home "/.config/mpd")))
        (mkdir-p mpd-dir)
        (copy-file #$mpd-config (string-append mpd-dir "/mpd.conf"))
        (let ((uid (passwd:uid (getpw "neg")))
              (gid (passwd:gid (getpw "neg"))))
          (chown (string-append mpd-dir "/mpd.conf") uid gid)))
      ;; Greetd config
      (mkdir-p "/etc/greetd")
      (copy-file #$greetd-config "/etc/greetd/config.toml")))

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

  (users (cons (user-account
    (name "neg") (comment "neg")
    (password (crypt "neg" "$6$rounds=4096$abcdefgh"))
    (group "users")
    (supplementary-groups '("wheel" "netdev" "audio" "video" "kvm" "input" "dialout"))
    (shell (file-append zsh "/bin/zsh")))
    %base-user-accounts))

  (sudoers-file (plain-file "sudoers" "\
root ALL=(ALL) ALL
%wheel ALL=NOPASSWD: ALL\n"))

  (pam-services
    (base-pam-services #:allow-empty-passwords? #t))

  (setuid-programs
    (cons* (setuid-program
             (program (file-append sudo "/bin/sudo")))
           %setuid-programs))

  (packages
    (append
      (specifications->packages
        (list
          "zsh" "git" "neovim" "tmux" "bat" "fd" "ripgrep"
          "btop" "htop" "rsync" "btrfs-progs" "smartmontools"
          "curl" "wget"
          "python" "python-pip" "node"
          "make" "gcc-toolchain" "expect"
          "go" "podman"
          "socat" "nmap" "iperf" "lsof" "mtr" "tcpdump"
          "traceroute" "fping" "iwd" "dnsmasq" "unbound"
          "strace" "tree" "jq" "less" "lvm2" "xfsprogs"
          "dosfstools" "efibootmgr" "cpio" "dash"
          "patchelf" "pigz" "pv" "progress"
          "tealdeer" "direnv" "difftastic" "just" "shellcheck"
          "pandoc" "graphviz" "git-lfs" "git-crypt"
          "git-delta" "git-extras" "zoxide" "mpv"
          "abduco" "age" "alsa-utils" "aria2" "atop"
          "chezmoi" "cowsay" "entr" "eza" "fastfetch"
          "fclones" "figlet" "fio" "helix" "hexyl"
          "hyperfine" "hwinfo" "iftop" "inotify-tools"
          "jpegoptim" "jujutsu" "lolcat" "mandoc"
          "mediainfo" "miller" "minicom" "nano" "ncdu"
          "neomutt" "pngquant" "powertop" "pre-commit"
          "pwgen" "scc" "shfmt" "sox" "sshfs"
          "stress-ng" "toilet" "ugrep" "uv" "vale"
          "valgrind" "vim" "vnstat" "watchexec" "whois"
          "python-yamllint" "zathura"
          "borg" "hashcat"
          "wl-clipboard" "wlogout" "wlr-randr" "wofi" "wtype"
          "hyprland" "hyprlock" "hypridle" "hyprpicker"
          "kate" "ark" "konsole"
          "alacritty" "foot" "kitty" "greetd" "tuigreet"
          "icecat" "ungoogled-chromium-wayland"
          "mangohud" "syncthing"
          ;; === PACKAGE PARITY WITH NIXOS VM ===
          "dunst" "grim" "slurp" "swappy" "xdg-desktop-portal-hyprland"
          "yt-dlp" "swayimg"
          "gnome-keyring" "gnome-system-monitor" "gnome-text-editor" "gnome-tweaks"
          "nautilus" "gnome-control-center" "gnome-disk-utility"
          "xdg-utils" "yelp"
          "clang" "cmake" "gdb" "fzf" "sqlite" "lldb" "meson" "ninja"
          "binutils" "pkg-config" "autoconf" "automake" "libtool"
          "flex" "bison" "ruby" "subversion" "pipx"
          "nethogs"
          "wireplumber" "pipewire" "pavucontrol"
          "ffmpeg" "ffmpegthumbnailer" "imagemagick"
          "font-jetbrains-mono"
          "parted" "sysstat" "cups" "slirp4netns" "skopeo"
          "age-plugin-yubikey" "avahi" "bpftrace" "cava" "ccid"
          "cdparanoia" "chafa" "chromaprint" "cliphist" "convmv"
          "curlie" "ddrescue" "diff-so-fancy" "distrobox"
          "dive" "enca" "freerdp" "fwupd" "goaccess" "gptfdisk"
          "gvfs" "htmlq" "iotop" "isync" "jc"
          "kexec-tools" "libnotify" "liquidctl" "lm-sensors"
          "lowdown" "lshw" "lsp-plugins" "man-pages" "memtester"
          "moreutils" "multipath-tools" "nuspell" "openocd"
          "openrgb" "optipng" "ouch" "parallel" "pastel"
          "pbzip2" "pcmanfm" "pcsc-tools" "pgcli" "picard"
          "plocate" "qemu" "qpwgraph" "qrencode"
          "rclone" "recoll" "reptyr" "rlwrap" "sshpass" "sudo"
          "telegram-desktop" "tig" "toilet" "transmission"
          "tree-sitter" "tumbler" "udiskie" "unzip" "upower"
          "urlscan" "vdirsyncer" "virt-manager" "virt-viewer"
          "w3m" "waypipe" "wayvnc" "wev" "wf-recorder" "which"
          "ydotool" "zbar" "zk" "i3status" "inxi" "orca"
          "dualsensectl" "gallery-dl" "hw-probe" "newsraft"
          "patool" "ttfautohint" "wget2" "wlogout"
          "du-dust" "yq" "python-scour"
          "tesseract-ocr" "wireshark" "adb"
          "bmon" "hunspell"))
       ;; Custom channel packages (not available in Guix mainline)
       (list tailscale ollama gopass
             gh-cli glow-markdown lazygit-bin zellij-bin
             localsend oh-my-posh act-bin xdg-ninja jdupes
             yazi ruff-linter gitleaks-sec
             ttyd-share genact-activity ctop-monitor
             ;; 5th pass — verified URLs + hashes
             onefetch-info erdtree-disk bandwhich-net resvg-render
             ;; 6th pass — GitHub API verified
             doggo-dns xh-client lnav-log
             ;; 7th pass — single binary releases
             cpufetch-tool viu-viewer
             ;; 8th pass — DEB + gzip + single binary
             sops-secrets taplo-fmt tabiew-tui
             ;; 9th pass — DEB zstd
             sad-editor
             ;; source-based packages
             ioping
             nicotine+
             hunspell-dict-ru
             dcfldd
             ;; 9th pass — AI agents
             goose-ai
             ;; Wayland wallpaper daemon (fork of swww, Vulkan)
             wl
             advancecomp ddccontrol par
             themix-theme-oomox
             quickshell ambxst axctl-compositor)
      %base-packages))

  (services
    (let* ((base (remove
                   (lambda (svc)
                     (let ((t (service-kind svc)))
                       (memq t (list gdm-service-type
                                     sddm-service-type
                                     slim-service-type
                                     wpa-supplicant-service-type
                                     network-manager-service-type
                                     modem-manager-service-type
                                     cups-pk-helper-service-type))))
                   (modify-services %desktop-services
                     (login-service-type config =>
                       (login-configuration
                         (inherit config)
                         (motd vm-image-motd)))
                     (guix-service-type config =>
                       (guix-configuration
                         (inherit config)
                         (guix (current-guix))
                         (extra-options
                           (list "--cores=16" "--max-jobs=8"))
                         (substitute-urls
                           (list "https://mirror.yandex.ru/mirrors/guix/"
                                 "https://substitutes.nonguix.org")))))))
             (greetd-svc
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
                         (auto-start? #t))))))
      (cons* (service openssh-service-type
               (openssh-configuration
                 (port-number 2222)
                 (password-authentication? #t)))
             (service spice-vdagent-service-type)
             (service dhcpcd-service-type)
             (service unbound-service-type)
             ;; Shepherd services
             (simple-service 'mpd-shepherd
               shepherd-root-service-type
               (list mpd-shepherd-service))
             (simple-service 'tailscale-shepherd
               shepherd-root-service-type
               (list tailscale-shepherd-service))
             (simple-service 'ollama-shepherd
               shepherd-root-service-type
               (list ollama-shepherd-service))
             ;; System config deployment on every reconfigure
             (simple-service 'system-config-activation
               activation-service-type
               system-config-activation)
             greetd-svc
             base)))

  (name-service-switch %mdns-host-lookup-nss))
