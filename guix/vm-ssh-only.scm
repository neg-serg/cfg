;; Ultra-minimal bootable VM with SSH only
(use-modules (gnu) (guix) (srfi srfi-1))
(use-service-modules networking ssh)
(use-package-modules base bash ssh shells)

(operating-system
  (host-name "guix-eval")
  (timezone "Europe/Moscow")
  (locale "en_US.utf8")
  (keyboard-layout (keyboard-layout "us,ru"))
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
    (supplementary-groups '("wheel"))
    (shell (file-append bash "/bin/bash")))
    %base-user-accounts))
  (sudoers-file (plain-file "sudoers" "\
root ALL=(ALL) ALL
%wheel ALL=NOPASSWD: ALL\n"))
  (packages (append (list openssh bash) %base-packages))
  (services (cons*
    (service openssh-service-type
      (openssh-configuration
        (port-number 22)
        (password-authentication? #t)))
    (service dhcp-client-service-type)
    %base-services)))
