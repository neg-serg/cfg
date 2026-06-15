(define-module (custom packages ghostty-bin)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix download)
  #:use-module (guix build-system trivial)
  #:use-module ((guix licenses) #:prefix license:))

(define-public ghostty-bin
  (package
    (name "ghostty-bin")
    (version "1.3.1")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "https://github.com/pkgforge-dev/ghostty-appimage"
                    "/releases/download/v" version
                    "/Ghostty-" version "-x86_64.AppImage"))
              (sha256
               (base32
                "0a6wh96s2516g81s31mdx02x63g3mbqvnyb8frw1kzbaf4mqvr7x"))))
    (build-system trivial-build-system)
    (arguments
     (list
      #:modules '((guix build utils))
      #:builder
      #~(begin
          (use-modules (guix build utils))
          (let* ((source (assoc-ref %build-inputs "source"))
                 (out    (assoc-ref %outputs "out"))
                 (bin    (string-append out "/bin")))
            (mkdir-p bin)
            (copy-file source (string-append bin "/ghostty"))
            (chmod (string-append bin "/ghostty") #o555)))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://ghostty.org")
    (synopsis "Fast, feature-rich, cross-platform terminal emulator (pre-built AppImage)")
    (description "Ghostty is a terminal emulator that differentiates itself by
being fast, feature-rich, and native.  This package provides a pre-built
AppImage binary from the community ghostty-appimage project.")
    (license license:expat)))

ghostty-bin
