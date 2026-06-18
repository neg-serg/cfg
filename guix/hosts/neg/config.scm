(use-modules (gnu) (guix))
(use-service-modules networking ssh desktop base)
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
                          (device (uuid "a402bcc9-3489-4143-a72d-89e3a375e443" 'btrfs))
                          (type "btrfs")
                          (options "compress=zstd,noatime"))
                       %base-file-systems))
  (users (cons (user-account
    (name "neg")
    (group "users")
    (supplementary-groups '("wheel" "netdev" "audio" "video" "kvm" "input"))
    (password (crypt "123" "$6$oX65X4lU2kbjcxsk$gTuIcPinBdrxsdsZEoslz7uh4dREQteCuw690EwQi0AUVUqkWDK.YTjklGItSjXuzVPnZCGKStYtiEuHR2E1p0"))
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
    (list
      ;; ── Shell / Core CLI ──
      (specification->package "zsh")            ; login shell
      (specification->package "git")            ; version control
      (specification->package "neovim")         ; editor
      (specification->package "tmux")           ; terminal multiplexer
      (specification->package "bat")            ; cat with syntax highlighting
      (specification->package "fd")             ; modern find
      (specification->package "ripgrep")        ; modern grep
      (specification->package "eza")            ; modern ls
      (specification->package "fzf")            ; fuzzy finder
      (specification->package "zoxide")         ; smart cd
      (specification->package "direnv")         ; per-directory env
      (specification->package "chezmoi")        ; dotfile manager
      (specification->package "jq")             ; JSON processor
      (specification->package "yq")             ; YAML processor
      (specification->package "tealdeer")       ; simplified man pages
      (specification->package "hexyl")          ; hex viewer
      (specification->package "tree")           ; directory tree
      (specification->package "entr")           ; file watcher
      (specification->package "rlwrap")         ; readline wrapper
      (specification->package "cowsay")         ; cow says things
      (specification->package "figlet")         ; ASCII art text
      (specification->package "lolcat")         ; rainbow output
      ;; ── Monitoring / System ──
      (specification->package "btop")           ; resource monitor
      (specification->package "htop")           ; process viewer
      (specification->package "fastfetch")      ; system info
      (specification->package "bottom")         ; graphical process monitor
      (specification->package "powertop")       ; power consumption
      (specification->package "cpupower")       ; CPU frequency control
      (specification->package "turbostat")      ; CPU turbo stats
      (specification->package "hwinfo")         ; hardware info
      (specification->package "smartmontools")  ; S.M.A.R.T. disk health
      (specification->package "ncdu")           ; disk usage
      (specification->package "plocate")        ; file indexer
      (specification->package "progress")       ; show coreutils progress
      (specification->package "atop")           ; advanced system monitor
      ;; ── Network / Remote ──
      (specification->package "curl")           ; HTTP client
      (specification->package "wget")           ; downloader
      (specification->package "aria2")          ; multi-protocol downloader
      (specification->package "openssh")        ; SSH server + client
      (specification->package "rsync")          ; file sync
      (specification->package "nmap")           ; network scanner
      (specification->package "tcpdump")        ; packet analyzer
      (specification->package "mtr")            ; traceroute + ping
      (specification->package "socat")          ; socket relay
      (specification->package "nethogs")        ; per-process network
      (specification->package "iftop")          ; bandwidth monitor
      (specification->package "vnstat")         ; traffic logger
      (specification->package "traceroute")     ; network path
      (specification->package "wireguard-tools") ; VPN
      (specification->package "network-manager") ; NetworkManager daemon
      (specification->package "bluez")          ; Bluetooth
      ;; ── Development ──
      (specification->package "python")         ; Python 3
      (specification->package "node")           ; Node.js
      (specification->package "rust")           ; Rust toolchain
      (specification->package "go")             ; Go compiler
      (specification->package "make")           ; build automation
      (specification->package "gcc-toolchain")  ; C/C++ compiler
      (specification->package "cmake")          ; build system
      (specification->package "meson")          ; build system
      (specification->package "ninja")          ; fast build executor
      (specification->package "gdb")            ; debugger
      (specification->package "valgrind")       ; memory profiler
      (specification->package "clang")          ; LLVM C compiler
      (specification->package "lldb")           ; LLVM debugger
      (specification->package "tig")            ; git TUI
      (specification->package "git-crypt")      ; git encryption
      (specification->package "git-lfs")        ; git large files
      (specification->package "hyperfine")      ; benchmark tool
      (specification->package "difftastic")     ; structural diff
      (specification->package "just")           ; command runner
      (specification->package "shellcheck")     ; shell lint
      (specification->package "shfmt")          ; shell formatter
      (specification->package "vale")           ; prose linter
      (specification->package "sbcl")           ; Common Lisp
      ;; ── System Tools ──
      (specification->package "strace")         ; syscall tracer
      (specification->package "lsof")           ; list open files
      (specification->package "fio")            ; IO benchmark
      (specification->package "pv")             ; pipe viewer
      (specification->package "rclone")         ; cloud storage sync
      (specification->package "restic")         ; backup tool
      (specification->package "borg")           ; deduplicating backup
      (specification->package "age")            ; file encryption
      (specification->package "pwgen")          ; password generator
      (specification->package "efibootmgr")     ; EFI boot manager
      (specification->package "lvm2")           ; LVM tools
      (specification->package "xfsprogs")       ; XFS utilities
      (specification->package "dash")           ; POSIX shell
      (specification->package "ddrescue")       ; data recovery
      (specification->package "expect")         ; automate interactive programs
      (specification->package "fclones")        ; duplicate file finder
      (specification->package "moreutils")      ; extra unix tools
      (specification->package "udiskie")        ; auto-mount removable media
      (specification->package "abduco")         ; session manager
      (specification->package "diff-so-fancy")  ; human-friendly diffs
      (specification->package "dool")           ; system stats (dstat successor)
      ;; ── Media / Graphics ──
      (specification->package "mpv")            ; media player
      (specification->package "ffmpeg")         ; multimedia framework
      (specification->package "yt-dlp")         ; video downloader
      (specification->package "streamlink")     ; stream extractor
      (specification->package "imagemagick")    ; image manipulation
      (specification->package "gimp")           ; image editor
      (specification->package "inkscape")       ; vector graphics
      (specification->package "blender")        ; 3D graphics
      (specification->package "obs")            ; streaming/recording
      (specification->package "sox")            ; audio processing
      (specification->package "easyeffects")    ; audio effects
      (specification->package "carla")          ; audio plugin host
      (specification->package "helvum")         ; PipeWire patchbay
      (specification->package "beets")          ; music library manager
      (specification->package "picard")         ; MusicBrainz tagger
      ;; ── Containers / Virtualization ──
      (specification->package "podman")         ; rootless containers
      (specification->package "docker")         ; container runtime
      (specification->package "distrobox")      ; containerized distros
      (specification->package "skopeo")         ; container image ops
      (specification->package "dive")           ; container image analyzer
      ;; ── Desktop / Wayland / Hyprland ──
      (specification->package "hyprland")       ; Wayland compositor
      (specification->package "hypridle")       ; idle daemon
      (specification->package "hyprlock")       ; screen locker
      (specification->package "hyprpicker")     ; color picker
      (specification->package "hyprpaper")      ; wallpaper daemon
      (specification->package "xdg-desktop-portal-hyprland") ; screen share backend
      (specification->package "kitty")          ; GPU terminal
      (specification->package "alacritty")      ; GPU terminal
      (specification->package "foot")           ; Wayland terminal
      (specification->package "wezterm")        ; GPU terminal
      (specification->package "wlogout")        ; logout menu
      (specification->package "dunst")          ; notification daemon
      (specification->package "slurp")          ; region selector
      (specification->package "grim")           ; screenshot
      (specification->package "swappy")         ; screenshot editor
      (specification->package "swaybg")         ; wallpaper renderer
      (specification->package "swayimg")        ; image viewer
      (specification->package "wl-clipboard")   ; clipboard manager
      (specification->package "cliphist")       ; clipboard history
      (specification->package "wf-recorder")    ; screen recorder
      (specification->package "playerctl")      ; media key control
      (specification->package "wireplumber")    ; PipeWire session manager
      (specification->package "pavucontrol")    ; PulseAudio volume control
      (specification->package "greetd")         ; login daemon
      (specification->package "tuigreet")       ; console greeter
      ;; ── KDE / GNOME utilities ──
      (specification->package "ark")            ; archive manager
      (specification->package "kate")           ; advanced text editor
      (specification->package "konsole")        ; KDE terminal
      (specification->package "breeze")         ; KDE Breeze theme
      (specification->package "breeze-icons")   ; KDE Breeze icons
      (specification->package "gnome-shell")    ; GNOME Shell (fallback DE)
      (specification->package "gdm")            ; GNOME Display Manager (fallback)
      (specification->package "gnome-control-center") ; GNOME settings
      ;; ── Communication ──
      (specification->package "neomutt")        ; email client
      (specification->package "isync")          ; mail sync (mbsync)
      (specification->package "vdirsyncer")     ; calendar/contacts sync
      ;; ── Documents / Reading ──
      (specification->package "zathura")        ; PDF viewer
      (specification->package "zathura-pdf-poppler") ; PDF backend
      (specification->package "pandoc")         ; document converter
      ;; ── Fonts / Theming ──
      (specification->package "font-jetbrains-mono") ; monospace font
      (specification->package "font-fira-code") ; monospace font
      (specification->package "font-google-noto") ; comprehensive unicode font
      (specification->package "font-dejavu")    ; default GUI font
      (specification->package "qt5ct")          ; Qt5 theme selector
      (specification->package "qt6ct")          ; Qt6 theme selector
      (specification->package "nss-certs")      ; TLS certificates (included in %base-packages, kept explicit)
      ;; ── Gaming ──
      (specification->package "steam")          ; game platform
      ;; ── Browser ──
      (specification->package "firefox")        ; web browser
      ;; ── Misc ──
      (specification->package "telegram-desktop") ; messenger
      (specification->package "syncthing")      ; file sync
      (specification->package "qrencode")       ; QR code generator
      (specification->package "ranger")         ; terminal file manager
      (specification->package "notmuch")        ; mail indexer
      (specification->package "jujutsu")        ; git-compatible VCS
      (specification->package "nethack")        ; roguelike game
      (specification->package "subversion")     ; SVN client
      (specification->package "fzf")            ; fuzzy finder
      (specification->package "fd")             ; modern find
      (specification->package "ripgrep")        ; modern grep
      (specification->package "difftastic")     ; structural diff
      (specification->package "ugrep")          ; ultra-fast grep
      )
    all-custom-packages
    %base-packages))
  (services
    (cons* (service greetd-service-type
             (greetd-configuration
               (terminals
                 (list
                   (greetd-terminal-configuration
                     (terminal-vt "7")
                     (terminal-switch #t)
                     (default-session-command
                       (greetd-agreety-session
                         (extra-env
                           '(("XDG_SESSION_TYPE" . "wayland")
                             ("XDG_CURRENT_DESKTOP" . "Hyprland")))
                         (command
                           (file-append
                             (specification->package "hyprland")
                             "/bin/Hyprland")))))))))
           (service openssh-service-type
             (openssh-configuration
               (port-number 22)
               (password-authentication? #t)))
           %desktop-services)))
