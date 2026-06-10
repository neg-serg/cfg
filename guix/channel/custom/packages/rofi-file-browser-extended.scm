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
                  (add-after 'unpack 'fix-werror
                    (lambda _
                      (substitute* "CMakeLists.txt"
                        (("-Werror") ""))
                      #t)))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/marvinkreis/rofi-file-browser-extended")
    (synopsis "Rofi plugin for file browsing")
    (description "Rofi plugin for file browsing with recursive listing and custom commands.")
    (license expat)))

rofi-file-browser-extended
