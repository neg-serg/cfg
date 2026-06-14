(define-module (custom packages rofi-file-browser-extended)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system cmake)
  #:use-module (guix licenses)
  #:use-module (gnu packages xdisorg)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages cmake))

(define-public rofi-file-browser-extended
  (package
    (name "rofi-file-browser-extended")
    (version "1.3.1")
    (source (origin
              (method url-fetch)
              (uri "https://github.com/marvinkreis/rofi-file-browser-extended/archive/refs/tags/1.3.1.tar.gz")
              (sha256 (base32 "0q2600zfb3waza0k61yab3kjja3f1clyvr3sdrz79p9k2mkhw0cy"))))
    (build-system cmake-build-system)
    (native-inputs (list pkg-config cmake))
    (inputs (list rofi))
    (arguments '(#:tests? #f
       #:phases (modify-phases %standard-phases
                   (add-after 'unpack 'fix-incompatible-pointer-types
                     (lambda _
                       (substitute* "src/filebrowser.c"
                         (("static cairo_surface_t \\*file_browser_get_icon \\( const Mode \\*sw, unsigned int selected_line, int height \\)")
                          "static cairo_surface_t *file_browser_get_icon ( const Mode *sw, unsigned int selected_line, unsigned int height )"))
                       #t))
                   (add-after 'unpack 'fix-install-dirs
                     (lambda _
                       (substitute* "CMakeLists.txt"
                         (("\\$\\{ROFI_PLUGINS_DIR\\}") "lib/rofi")
                         (("/usr/share/man/man1") "share/man/man1"))
                       #t)))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/marvinkreis/rofi-file-browser-extended")
    (synopsis "Rofi plugin for file browsing")
    (description "Rofi plugin for file browsing with recursive listing and custom commands.")
    (license expat)))

rofi-file-browser-extended
