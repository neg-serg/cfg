(use-modules (gnu) (guix))
(use-service-modules networking ssh)
(use-package-modules base bash certs ssh version-control curl)

(operating-system
  (host-name "guix") (timezone "Europe/Moscow") (locale "en_US.utf8")
  (bootloader (bootloader-configuration (bootloader grub-bootloader) (targets (quote ("/dev/vda")))))
  (file-systems (cons (file-system (mount-point "/") (device (file-system-label "Guix_image")) (type "ext4")) %base-file-systems))
  (users (cons* (user-account
    (name "guest") (group "users") (password (crypt "guix" "$6$rounds=4096"))
    (supplementary-groups (quote ("wheel" "netdev" "audio" "video")))
    (shell (file-append bash "/bin/bash"))) %base-user-accounts))
  (sudoers-file (plain-file "sudoers" "root ALL=(ALL) ALL\n%wheel ALL=NOPASSWD: ALL\n"))
  (packages (append (list bash coreutils openssh git curl) %base-packages))
  (services (cons* (service openssh-service-type (openssh-configuration (port-number 2222) (password-authentication? #t)))
                   %base-services)))
