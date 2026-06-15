(define-module (custom packages satty)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module (guix build-system cargo)
  #:use-module (guix licenses)
  #:use-module (gnu packages gtk)
  #:use-module (gnu packages glib)
  #:use-module (gnu packages gnome)
  #:use-module (gnu packages fontutils)
  #:use-module (gnu packages gl)
  #:use-module (gnu packages pkg-config))

(define-public satty
  (package
    (name "satty")
    (version "0.16.0")
    (source (origin
              (method git-fetch)
              (uri (git-reference
                    (url "https://github.com/gabm/Satty")
                    (commit (string-append "v" version))))
              (file-name (git-file-name name version))
              (sha256 (base32 "0000000000000000000000000000000000000000000000000000"))))
    (build-system cargo-build-system)
    (native-inputs (list pkg-config))
    (inputs (list gtk
                  gtk-layer-shell
                  cairo
                  pango
                  glib
                  gdk-pixbuf
                  libadwaita
                  fontconfig
                   libepoxy))
    (arguments
     '(#:install-source? #f))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/gabm/Satty")
    (synopsis "Screenshot annotation tool inspired by Swappy and Flameshot")
    (description "Satty is a modern screenshot annotation tool for Wayland
compositors.  It provides on-screen drawing, text, arrows, and shape tools
for annotating screenshots after capture.")
    (license gpl3+)))

satty
