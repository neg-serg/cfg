(define-module (custom packages youtube-tui)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system cargo)
  #:use-module ((guix licenses) #:prefix license:))

(define-public youtube-tui
  (package
    (name "youtube-tui")
    (version "0.9.4")
    (source (origin
              (method url-fetch)
              (uri (crate-uri "youtube-tui" version))
              (file-name (string-append name "-" version ".tar.gz"))
              (sha256 (base32 "1y8wb690r6271bkgic3smx557balmpjniys7kj9xwzf3zcxwx4g4"))))
    (build-system cargo-build-system)
    (home-page "https://tui.siri.ws/youtube")
    (synopsis "YouTube TUI")
    (description "An aesthetically pleasing YouTube TUI written in Rust.")
    (license license:gpl3+)))

youtube-tui
