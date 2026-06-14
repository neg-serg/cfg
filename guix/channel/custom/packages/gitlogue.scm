(define-module (custom packages gitlogue)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system cargo)
  #:use-module (guix licenses))

(define-public gitlogue
  (package
    (name "gitlogue")
    (version "0.1.3")
    (source (origin
              (method url-fetch)
              (uri (crate-uri "gitlogue" version))
              (file-name (string-append name "-" version ".tar.gz"))
              (sha256 (base32 "0000000000000000000000000000000000000000000000000000"))))
    (build-system cargo-build-system)
    (arguments
     '(#:install-source? #f))
    (home-page "https://github.com/ankitects/gitlogue")
    (synopsis "Interactive Git history browser")
    (description "Gitlogue is an interactive terminal-based tool for browsing
and exploring Git commit history with a split-panel interface showing the diff
and metadata for each commit.")
    (license expat)))

gitlogue
