(define-module (custom packages matugen)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system copy)
  #:use-module (guix licenses)
  #:use-module (gnu packages compression))

(define-public matugen
  (package
    (name "matugen")
    (version "4.1.0")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://github.com/InioX/matugen/releases/download/v"
                                  version "/matugen-" version "-x86_64.tar.gz"))
              (sha256 (base32 "1c5y809qvj9652xza9i96m9ivs4vapgjdxa44va85ivqsljc6ims"))))
    (build-system copy-build-system)
    (arguments
     '(#:install-plan `(("matugen" "bin/"))
       #:tests? #f
       #:strip-binaries? #f
       #:validate-runpath? #f))
    (home-page "https://github.com/InioX/matugen")
    (synopsis "Material You color generator")
    (description "Matugen is a tool for generating Material You color schemes
from wallpapers.  It can export color palettes for various applications
including GTK, Qt, Hyprland, Alacritty, and more.")
    (license gpl3+)))

matugen
