(define-module (custom packages htmlq)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system cargo)
  #:use-module (guix licenses))

(define-public htmlq
  (package
    (name "htmlq")
    (version "0.4.0")
    (source (origin
              (method url-fetch)
              (uri (crate-uri "htmlq" version))
              (file-name (string-append name "-" version ".tar.gz"))
              (sha256 (base32 "0000000000000000000000000000000000000000000000000000"))))
    (build-system cargo-build-system)
    (arguments
     '(#:install-source? #f))
    (home-page "https://github.com/mgdm/htmlq")
    (synopsis "Like jq, but for HTML")
    (description "Htmlq is a command-line tool for extracting content from
HTML files using CSS selectors.  It's similar to jq but for HTML documents.")
    (license expat)))

htmlq
