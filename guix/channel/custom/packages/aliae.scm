(define-module (custom packages aliae)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses)
  #:use-module (gnu packages elf))

(define-public aliae
  (package
    (name "aliae")
    (version "0.26.6")
    (source (origin
              (method url-fetch)
              (uri "https://github.com/JanDeDobbeleer/aliae/releases/download/v0.26.6/aliae-linux-amd64")
              (sha256 (base32 "0hr42rdlgfzs739favzjsa28f67v48830b794wn2aka6nxabx2w0"))))
    (build-system gnu-build-system)
    (native-inputs (list patchelf))
    (arguments
     '(#:tests? #f #:strip-binaries? #f #:validate-runpath? #f
       #:phases (modify-phases %standard-phases
         (delete 'bootstrap) (delete 'configure) (delete 'check) (delete 'build)
         (delete 'patch-usr-bin-file) (delete 'patch-source-shebangs)
         (delete 'patch-generated-file-shebangs)
         (replace 'unpack
           (lambda* (#:key source #:allow-other-keys)
             (symlink source "aliae-linux-amd64")
             #t))
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (let* ((out  (assoc-ref outputs "out"))
                    (bin  (string-append out "/bin"))
                    (glibc (assoc-ref %build-inputs "libc"))
                    (interp (string-append glibc "/lib/ld-linux-x86-64.so.2"))
                    (pe   (string-append (assoc-ref %build-inputs "patchelf")
                                         "/bin/patchelf")))
               (mkdir-p bin)
               (install-file "aliae-linux-amd64" bin)
               (chmod (string-append bin "/aliae-linux-amd64") #o755)
               (invoke pe "--set-interpreter" interp
                       (string-append bin "/aliae-linux-amd64"))
               #t))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://aliae.dev")
    (synopsis "Cross-shell alias manager")
    (description "Cross shell and platform alias management.")
    (license expat)))

aliae
