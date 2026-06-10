;;; guix-ru.scm — Guix OS configuration for a bootable installation image.
;;;
;;; Build ISO:
;;;   guix system disk-image --image-type=iso9660 guix-ru.scm
;;;
;;; Build USB-stick image (bigger, writable):
;;;   guix system disk-image guix-ru.scm
;;;
;;; Write to USB:
;;;   sudo dd if=/path/to/image of=/dev/sdX bs=4M status=progress
;;;
;;; ISO uses isolinux — make sure /dev/sdX is the *device*, not a partition.

(use-modules (gnu)
             (gnu services networking)
             (gnu services ssh)
             (gnu packages admin)
             (gnu packages compression)
             (gnu packages curl)
             (gnu packages disk)
             (gnu packages file)
             (gnu packages gnupg)
             (gnu packages linux)
             (gnu packages networking)
             (gnu packages package-management)
             (gnu packages pretty-print)
             (gnu packages rsync)
             (gnu packages shells)
             (gnu packages ssh)
             (gnu packages version-control)
             (gnu packages vim)
             (gnu packages wget)
             (srfi srfi-1))

(operating-system
  (host-name "guix-ru")
  (timezone "Europe/Moscow")
  (locale "ru_RU.UTF-8")

  (keyboard-layout
    (keyboard-layout "us,ru"
                     #:options '("grp:alt_shift_toggle")))

  (bootloader
    (bootloader-configuration
      (bootloader grub-bootloader)
      (targets '("/dev/sda"))
      (keyboard-layout keyboard-layout)))

  ;; Minimal root — на этапе установки монтируете свой раздел
  (file-systems
    (cons (file-system
            (device (file-system-label "root"))
            (mount-point "/")
            (type "ext4"))
          %base-file-systems))

  (users
    (cons* (user-account
             (name "user")
             (comment "Default user")
             (group "users")
             (home-directory "/home/user")
             (supplementary-groups '("wheel" "netdev" "audio" "video"))
             (password (crypt "guix" "$6$rounds=100000$salt")))
           %base-user-accounts))

  (sudoers-file
    (plain-file "sudoers"
                "root ALL=(ALL) ALL\n%wheel ALL=(ALL) ALL\n"))

  (packages
    (append (list
              ;; shell & tools
              zsh
              bash-completion
              htop
              git
              curl
              wget
              openssh
              gnupg
              nss-certs
              vim
              which
              file
              jq
              rsync
              ;; disk & recovery
              parted
              gparted
              ntfs-3g
              dosfstools
              exfat
              btrfs-progs
              xfsprogs
              mdadm
              cryptsetup
              lvm2
              ;; networking
              net-tools
              iproute2
              traceroute
              iptables
              network-manager
              iwd
              ;; archiving
              tar
              gzip
              xz
              unzip
              ;; Russian fonts (for tty/installer)
              font-tamzen)
            %base-packages))

  (services
    (append (list (service dhcp-client-service-type)
                  (service network-manager-service-type)
                  (service wpa-supplicant-service-type)
                  (service openssh-service-type
                           (openssh-configuration
                             (permit-root-login #t)
                             (password-authentication? #t)))
                  (service avahi-service-type))
            %desktop-services)))
