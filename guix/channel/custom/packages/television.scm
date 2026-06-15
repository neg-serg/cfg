(define-module (custom packages television)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses)
  #:use-module (gnu packages elf))

(define-public television
  (package
    (name "television")
    (version "0.15.9")
    (source
      (origin
        (method url-fetch)
        (uri (string-append
               "https://github.com/alexpasmantier/television/releases/download/"
               version "/tv-" version "-x86_64-unknown-linux-musl.tar.gz"))
        (sha256
          (base32
            "16p2yfpcgcj8y81wnmq6cd8iz8mk2n6g04f777a4zr7l690y641l"))))
    (build-system gnu-build-system)
    (native-inputs (list patchelf))
    (arguments
     `(#:tests? #f
       #:strip-binaries? #f
       #:validate-runpath? #f
       #:phases (modify-phases %standard-phases
         (delete 'configure)
         (delete 'check)
         (delete 'build)
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (let* ((out  (assoc-ref outputs "out"))
                    (bin  (string-append out "/bin"))
                    (glibc (assoc-ref %build-inputs "libc"))
                    (interp (string-append glibc "/lib/ld-linux-x86-64.so.2"))
                    (pe (string-append (assoc-ref %build-inputs "patchelf")
                                       "/bin/patchelf")))
               (mkdir-p bin)
               (install-file "tv" bin)
               (false-if-exception
                (invoke pe "--set-interpreter" interp
                        (string-append bin "/tv")))
               #t))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/alexpasmantier/television")
    (synopsis "Blazing fast general purpose fuzzy finder TUI")
    (description "Television is a fast and versatile fuzzy finder TUI
written in Rust.  It can search files, git repositories, environment
variables, and more with live preview support.")
    (license expat)))

television
