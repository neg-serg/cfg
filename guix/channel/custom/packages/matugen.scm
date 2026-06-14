(define-module (custom packages matugen)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system cargo)
  #:use-module (guix licenses))

(define-public matugen
  (package
    (name "matugen")
    (version "2.4.1")
    (source (origin
              (method url-fetch)
              (uri (crate-uri "matugen" version))
              (file-name (string-append name "-" version ".tar.gz"))
              (sha256 (base32 "0000000000000000000000000000000000000000000000000000"))))
    (build-system cargo-build-system)
    (arguments
     '(#:install-source? #f))
    (home-page "https://github.com/InioX/matugen")
    (synopsis "Material You color generator")
    (description "Matugen is a tool for generating Material You color schemes
from wallpapers.  It can export color palettes for various applications
including GTK, Qt, Hyprland, Alacritty, and more.")
    (license gpl3+)))

matugen
