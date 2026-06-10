(define-module (custom packages nicotine+)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module (guix utils)
  #:use-module (guix build-system python)
  #:use-module (guix licenses)
  #:use-module (gnu packages)
  #:use-module (gnu packages mp3)
  #:use-module (gnu packages python-xyz)
  #:use-module (gnu packages gtk)
  #:use-module (gnu packages glib)
  #:use-module (gnu packages gettext))

;; python-pytaglib with tests and wrap phase disabled
(define-public python-pytaglib-fixed
  (package
    (inherit python-pytaglib)
    (arguments
     (substitute-keyword-arguments (package-arguments python-pytaglib)
       ((#:tests? tests? #f) #f)
       ((#:phases phases '%standard-phases)
        `(modify-phases ,phases
           (delete 'wrap)))))))

;; nicotine+ — Python Soulseek client  
(define-public nicotine+
  (package
    (name "nicotine+")
    (version "3.3.10")
    (source (origin
              (method git-fetch)
              (uri (git-reference
                    (url "https://github.com/nicotine-plus/nicotine-plus")
                    (commit version)))
              (file-name (git-file-name name version))
              (sha256 (base32 "0xj7hlhgirgjyfmdchksvwhjhaqaf5n84brzih6fqlbsrr9gxkw9"))))
    (build-system python-build-system)
    (native-inputs (list gettext-minimal))
    (arguments '(#:tests? #f))
    (propagated-inputs
     (list python-pytaglib-fixed gtk+ python-pygobject))
    (home-page "https://nicotine-plus.org")
    (synopsis "Graphical Soulseek client")
    (description "Nicotine+ is a graphical client for the Soulseek P2P network.")
    (license gpl3+)))

nicotine+
