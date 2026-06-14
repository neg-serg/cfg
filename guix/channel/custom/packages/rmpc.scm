(define-module (custom packages rmpc)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system cargo)
  #:use-module (guix licenses)
  #:use-module (gnu packages crates-io))

(define-public rmpc
  (package
    (name "rmpc")
    (version "0.7.0")
    (source (origin
              (method url-fetch)
              (uri (crate-uri "rmpc" version))
              (file-name (string-append name "-" version ".tar.gz"))
              (sha256 (base32 "0000000000000000000000000000000000000000000000000000"))))
    (build-system cargo-build-system)
    (arguments
     '(#:install-source? #f))
    (home-page "https://github.com/mierak/rmpc")
    (synopsis "Beautiful and configurable TUI MPD client")
    (description "Rmpc is a fast, beautiful, and configurable terminal user
interface client for the Music Player Daemon (MPD).  It features album art
display, library browsing, playlist management, and a clean Rust-based TUI.")
    (license gpl3+)))

rmpc
