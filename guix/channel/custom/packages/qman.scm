(define-module (custom packages qman)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module (guix build-system meson)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages man)
  #:use-module (gnu packages ncurses)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages python-xyz))

(define-public qman
  (package
    (name "qman")
    (version "1.5.1")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/plp13/qman")
             (commit (string-append "v" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "0q1g1fvipfk8vw432xiwm12rjb1hlyhmb6x6y99qc28wpinhnwng"))))
    (build-system meson-build-system)
    (native-inputs (list pkg-config python-cogapp))
    (inputs (list bzip2
                  man-db
                  ncurses
                  xz
                  zlib))
    (arguments '(#:tests? #f
                 #:configure-flags '("-Dtests=disabled"
                                     "-Dconfigdir=share/qman/config")))
    (home-page "https://github.com/plp13/qman")
    (synopsis "Modern man page viewer for the terminal")
    (description "qman is a modern manual page viewer for the terminal featuring
hyperlinks, browser-like navigation, a table of contents for each page,
incremental search, mouse support, navigation history, and configurable themes.
Written in C with minimal dependencies.")
    (license license:bsd-2)))

qman
