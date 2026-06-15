(define-module (custom packages ufw)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system python)
  #:use-module (guix licenses)
  #:use-module (gnu packages python)
  #:use-module (gnu packages linux))

(define-public ufw
  (package
    (name "ufw")
    (version "0.36.2")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://launchpad.net/ufw/0.36/" version
                                  "/+download/ufw-" version ".tar.gz"))
              (sha256 (base32 "1xcbhd1xck205vi5cm26z1ckgbhbnch2bv9p6pdl8szgxjgajmra"))))
    (build-system python-build-system)
    (inputs (list iptables))
    (arguments
     '(#:tests? #f
       #:phases (modify-phases %standard-phases
         (add-before 'build 'fix-setup
           (lambda* (#:key outputs #:allow-other-keys)
             (let ((out (assoc-ref outputs "out")))
               (substitute* "setup.py"
                 (("from distutils\\.command\\.install import install as _install")
                  "from setuptools.command.install import install as _install")
                 (("from distutils\\.core import setup")
                  "from setuptools import setup")
                 ;; Don't try to write to real /etc and /lib/ufw
                 (("real_confdir = os\\.path\\.join\\('/etc'\\)")
                  (string-append "real_confdir = '" out "/etc'"))
                 (("real_statedir = os\\.path\\.join\\('/lib', 'ufw'\\)")
                  (string-append "real_statedir = '" out "/lib/ufw'"))
                 ;; Real prefix should not be clobbered by --home
                 (("real_prefix = self\\.prefix\n.*if self\\.home != None")
                  "real_prefix = self.prefix\n        if self.home != None")))
             #t))
         (add-before 'build 'provide-iptables
           (lambda* (#:key inputs #:allow-other-keys)
             (let* ((iptables (assoc-ref inputs "iptables"))
                    (store-sbin (string-append iptables "/sbin")))
               (substitute* "setup.py"
                 (("\\['/usr/sbin'")
                  (string-append "['" store-sbin "', '/usr/sbin'")))
               ;; Symlink the sbin binaries so the install phase can find them
               (mkdir-p "sbin")
               (for-each
                (lambda (binary)
                  (symlink (string-append store-sbin "/" binary)
                           (string-append "sbin/" binary)))
                '("iptables" "ip6tables" "iptables-restore" "ip6tables-restore"))
               #t)))
         (add-after 'install 'wrap-path
           (lambda* (#:key inputs outputs #:allow-other-keys)
             (let* ((out (assoc-ref outputs "out"))
                    (iptables (assoc-ref inputs "iptables"))
                    (ipt-sbin (string-append iptables "/sbin")))
               (wrap-program (string-append out "/sbin/ufw")
                 `("PATH" ":" prefix (,ipt-sbin)))
               (when (file-exists? (string-append out "/lib/ufw/ufw-init-functions"))
                 (wrap-program (string-append out "/lib/ufw/ufw-init-functions")
                   `("PATH" ":" prefix (,ipt-sbin)))))
             #t)))))
    (home-page "https://launchpad.net/ufw")
    (synopsis "Uncomplicated Firewall for managing netfilter")
    (description "Ufw stands for Uncomplicated Firewall, and is a program for managing a netfilter firewall.  It provides a command line interface and aims to be uncomplicated and easy to use.")
    (license gpl3+)))

ufw
