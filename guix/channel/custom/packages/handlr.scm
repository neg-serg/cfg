(define-module (custom packages handlr)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses)
  #:use-module (gnu packages elf))

(define-public handlr
  (package
    (name "handlr")
    (version "0.13.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "https://github.com/Anomalocaridid/handlr-regex/"
                    "releases/download/v" version "/handlr"))
              (sha256
               (base32
                "0b7yfn22qb0aayr6n5a7mprr3p4s62lv2b5id3s0nlz2lxkz4ljr"))))
    (build-system gnu-build-system)
    (native-inputs (list patchelf))
    (arguments
     '(#:tests? #f
       #:strip-binaries? #f
       #:validate-runpath? #f
       #:phases (modify-phases %standard-phases
         (delete 'bootstrap)
         (delete 'configure)
         (delete 'check)
         (delete 'build)
         (delete 'patch-usr-bin-file)
         (delete 'patch-source-shebangs)
         (delete 'patch-generated-file-shebangs)
         (replace 'unpack
           (lambda* (#:key source #:allow-other-keys)
             (symlink source "handlr")
             #t))
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (let* ((out  (assoc-ref outputs "out"))
                    (bin  (string-append out "/bin"))
                    (glibc (assoc-ref %build-inputs "libc"))
                    (interp (string-append glibc "/lib/ld-linux-x86-64.so.2"))
                    (pe (string-append (assoc-ref %build-inputs "patchelf")
                                       "/bin/patchelf")))
               (mkdir-p bin)
               (install-file "handlr" bin)
               (chmod (string-append bin "/handlr") #o755)
               (invoke pe "--set-interpreter" interp
                          (string-append bin "/handlr"))
               #t))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/Anomalocaridid/handlr-regex")
    (synopsis "Powerful alternative to xdg-utils written in Rust")
    (description "Handlr is a fast, powerful alternative to xdg-utils
for managing default applications and MIME types.")
    (license expat)))

handlr
