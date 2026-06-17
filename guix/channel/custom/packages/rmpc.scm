(define-module (custom packages rmpc)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages elf))

(define-public rmpc
  (package
    (name "rmpc")
    (version "0.11.0")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://github.com/mierak/rmpc/releases/download/v"
                                  version "/rmpc-v" version "-x86_64-unknown-linux-gnu.tar.gz"))
              (sha256 (base32 "017n3xn5mlcwfpymarf7ynw3jrbwgf2fxd5b0w8ydbzhgivlngdh"))))
    (build-system gnu-build-system)
    (native-inputs (list patchelf))
    (arguments
     '(#:tests? #f #:strip-binaries? #f #:validate-runpath? #f
       #:phases (modify-phases %standard-phases
                  (delete 'bootstrap) (delete 'configure)
                  (delete 'check) (delete 'build)
                  (delete 'patch-usr-bin-file)
                  (delete 'patch-source-shebangs)
                  (delete 'patch-generated-file-shebangs)
                  (add-after 'unpack 'cd-to-source
                    (lambda _
                      (chdir "..")))
                  (replace 'install
                    (lambda* (#:key outputs inputs #:allow-other-keys)
                      (let* ((out (assoc-ref outputs "out"))
                             (bdir (string-append out "/bin"))
                             (glibc (assoc-ref %build-inputs "libc"))
                             (interp (string-append glibc
                                      "/lib/ld-linux-x86-64.so.2"))
                             (pe (string-append (assoc-ref inputs "patchelf")
                                               "/bin/patchelf")))
                        (mkdir-p bdir)
                        (copy-file "rmpc" (string-append bdir "/rmpc"))
                        (chmod (string-append bdir "/rmpc") #o755)
                        (invoke pe "--set-interpreter" interp
                                (string-append bdir "/rmpc"))))))))
    (home-page "https://github.com/mierak/rmpc")
    (synopsis "Beautiful and configurable TUI MPD client")
    (description "Rmpc is a fast, beautiful, and configurable terminal user
interface client for the Music Player Daemon (MPD).  It features album art
display, library browsing, playlist management, and a clean Rust-based TUI.")
    (license gpl3+)))

rmpc
