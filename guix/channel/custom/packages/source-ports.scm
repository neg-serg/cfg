(define-module (custom packages source-ports)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module (guix build-system cargo)
  #:use-module (guix build-system cmake)
  #:use-module (guix licenses)
  #:use-module (gnu packages)
  #:use-module (gnu packages base)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages tls)
  #:use-module (gnu packages autotools)
  #:use-module (gnu packages curl)
  #:use-module (gnu packages mpd))

(define-public dcfldd
  (package
    (name "dcfldd")
    (version "1.9.1")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://github.com/resurrecting-open-source-projects/dcfldd/"
                                  "archive/v" version ".tar.gz"))
              (sha256 (base32 "1n2bcjkcak2gxqkvs9nhv8hmp4bwyf7l7zzqxp1ydjw6f5ml1fgg"))))
    (build-system gnu-build-system)
    (native-inputs (list autoconf automake))
    (arguments '(#:tests? #f))
    (home-page "https://github.com/resurrecting-open-source-projects/dcfldd")
    (synopsis "Enhanced version of dd for forensics")
    (description "dcfldd is an enhanced version of GNU dd with features for forensics.")
    (license gpl3+)))

(define-public advancecomp
  (package
    (name "advancecomp")
    (version "2.6")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://github.com/amadvance/advancecomp"
                                  "/releases/download/v" version
                                  "/advancecomp-" version ".tar.gz"))
              (sha256 (base32 "13s9qf7ch3myj09g1n63p4dw2laibcbdzdp1rdqrfh20amrpfzdh"))))
    (build-system gnu-build-system)
    (native-inputs (list autoconf automake pkg-config))
    (inputs (list zlib))
    (home-page "https://www.advancemame.it")
    (synopsis "Recompression tools")
    (description "AdvanceCOMP recompression tools for ZIP, PNG, MNG and GZ files.")
    (license gpl2+)))
