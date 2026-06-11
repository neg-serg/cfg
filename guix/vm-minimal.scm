;; Minimal VM config for fast build — SSH + core tools only.
;; Full package parity deployed via guix system reconfigure after boot.
(use-modules (gnu) (guix) (srfi srfi-1))
(use-service-modules desktop networking ssh xorg spice shepherd dns)
(use-package-modules admin base bootloaders certs curl disk file
                     gnupg linux package-management rsync ssh shells
                     version-control vim wget)

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
    (password (crypt "neg" "$6$rounds=4096"))
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
          ;; Shell & core
          "zsh" "git" "neovim" "tmux" "curl" "wget"
          "htop" "btop" "rsync" "ripgrep" "fd" "bat"
          "jq" "tree" "less" "which"
          ;; SSH/network
          "openssh" "nmap" "socat" "iperf" "lsof"
          "tcpdump" "traceroute" "mtr"
          ;; Build tools (needed for guix pull)
          "gcc-toolchain" "make" "pkg-config"
          ;; Admin
          "strace" "lvm2" "xfsprogs" "dosfstools"
          "btrfs-progs" "smartmontools"
          ;; Archiving
          "gzip" "xz" "unzip" "tar"
          ;; Editor
          "vim" "nano"))
      %base-packages))

  (services
    (cons* 
      (service openssh-service-type
        (openssh-configuration
          (port-number 22)
          (password-authentication? #t)))
      (service dhcp-client-service-type)
      (modify-services (remove
                         (lambda (svc)
                           (memq (service-kind svc)
                                 (list gdm-service-type)))
                         %base-services)
        (guix-service-type config =>
          (guix-configuration
            (inherit config)
            (substitute-urls
              (list "https://mirror.yandex.ru/mirrors/guix/"
                    "https://bordeaux.guix.gnu.org"))
            (extra-options
              (list "--cores=8" "--max-jobs=4"))))))))
