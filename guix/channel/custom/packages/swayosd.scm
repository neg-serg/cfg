(define-module (custom packages swayosd)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module (guix build-system cargo)
  #:use-module (guix licenses)
  #:use-module (gnu packages gtk)
  #:use-module (gnu packages glib)
  #:use-module (gnu packages gnome)
  #:use-module (gnu packages fontutils)
  #:use-module (gnu packages gl)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages pulseaudio))

(define-public swayosd
  (package
    (name "swayosd")
    (version "0.1.1")
    (source (origin
              (method git-fetch)
              (uri (git-reference
                    (url "https://github.com/ErikReider/SwayOSD")
                    (commit (string-append "v" version))))
              (file-name (git-file-name name version))
              (sha256 (base32 "0000000000000000000000000000000000000000000000000000"))))
    (build-system cargo-build-system)
    (native-inputs (list pkg-config))
    (inputs (list gtk
                  gtk-layer-shell
                  pulseaudio
                  glib
                  cairo
                  pango))
    (arguments
     '(#:install-source? #f
       #:cargo-test-flags '("--"
                            "--skip=test_osd_window")))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/ErikReider/SwayOSD")
    (synopsis "OSD window for Sway and other Wayland compositors")
    (description "SwayOSD provides on-screen display (OSD) windows for
brightness, volume, and keyboard layout changes on Sway and similar
wlroots-based Wayland compositors.")
    (license gpl3+)))

swayosd
