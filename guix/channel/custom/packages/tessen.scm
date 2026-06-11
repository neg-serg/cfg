(define-module (custom packages tessen)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses))

(define-public tessen
  (package
    (name "tessen")
    (version "2.2.3")
    (source (origin
              (method git-fetch)
              (uri (git-reference
                    (url "https://github.com/ayushnix/tessen")
                    (commit (string-append "v" version))))
              (file-name (git-file-name name version))
              (sha256 (base32 "0000000000000000000000000000000000000000000000000000"))))
    (build-system gnu-build-system)
    (arguments
     '(#:tests? #f
       #:make-flags (list (string-append "PREFIX=" (assoc-ref %outputs "out")))
       #:phases (modify-phases %standard-phases
         (delete 'configure)
         (delete 'check))))
    (home-page "https://github.com/ayushnix/tessen")
    (synopsis "Interactive 2FA TUI for pass and gopass")
    (description "Tessen is an interactive menu to autotype and copy pass and
gopass data on Wayland compositors.")
    (license gpl2)))

tessen
