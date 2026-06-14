(define-module (custom packages television)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system cargo)
  #:use-module (guix licenses))

(define-public television
  (package
    (name "television")
    (version "0.11.3")
    (source (origin
              (method url-fetch)
              (uri (crate-uri "television" version))
              (file-name (string-append name "-" version ".tar.gz"))
              (sha256 (base32 "0000000000000000000000000000000000000000000000000000"))))
    (build-system cargo-build-system)
    (arguments
     '(#:install-source? #f))
    (home-page "https://github.com/alexpasmantier/television")
    (synopsis "Blazing fast general purpose fuzzy finder TUI")
    (description "Television is a fast and versatile fuzzy finder TUI
written in Rust.  It can search files, git repositories, environment
variables, and more with live preview support.")
    (license expat)))

television
