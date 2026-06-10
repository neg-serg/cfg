(define-module (custom packages source-misc)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses)
  #:use-module (gnu packages cmake))

;; fortune-mod — minimal build from tarball (try cmake)
(define-public fortune-mod
  (package
    (name "fortune-mod")
    (version "3.26.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "https://github.com/shlomif/fortune-mod/releases/download/"
                    "fortune-mod-" version "/fortune-mod-" version ".tar.xz"))
              (sha256 (base32 "0k7ypxj3gi24n4swc3n0x958msbg22a6n4q7j429kff9ra318kdc"))))
    (build-system gnu-build-system)
    (native-inputs (list cmake))
    (arguments
     '(#:tests? #f
       #:configure-flags '("-DCMAKE_INSTALL_PREFIX=")))
    (home-page "https://github.com/shlomif/fortune-mod")
    (synopsis "Fortune cookie generator")
    (description "Fortune-mod prints random fortune cookies.")
    (license gpl3+)))

fortune-mod
