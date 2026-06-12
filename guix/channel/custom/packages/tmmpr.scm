(define-module (custom packages tmmpr)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses)
  #:use-module (gnu packages elf))

(define-public tmmpr
  (package
    (name "tmmpr")
    (version "0.1.1")
    (source (origin
              (method url-fetch)
              (uri "https://github.com/tanciaku/tmmpr/releases/download/v0.1.1/tmmpr-linux-x86_64.tar.gz")
              (sha256 (base32 "1snada4197z4bvd0951yhdkxh1bzjbkvdx7xa60wabjgqfclghiz"))))
    (build-system gnu-build-system)
    (native-inputs (list patchelf))
    (arguments
     '(#:tests? #f #:strip-binaries? #f #:validate-runpath? #f
       #:phases (modify-phases %standard-phases
         (delete 'bootstrap) (delete 'configure) (delete 'check) (delete 'build)
         (delete 'patch-usr-bin-file) (delete 'patch-source-shebangs)
         (delete 'patch-generated-file-shebangs)
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (let* ((out  (assoc-ref outputs "out"))
                    (bin  (string-append out "/bin"))
                    (glibc (assoc-ref %build-inputs "libc"))
                    (interp (string-append glibc "/lib/ld-linux-x86-64.so.2"))
                    (pe   (string-append (assoc-ref %build-inputs "patchelf")
                                         "/bin/patchelf")))
               (mkdir-p bin)
               (install-file "tmmpr" bin)
               (chmod (string-append bin "/tmmpr") #o755)
               (false-if-exception (invoke pe "--set-interpreter" interp
                       (string-append bin "/tmmpr")))
               #t))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/tanciaku/tmmpr")
    (synopsis "TUI MPRIS player")
    (description "TUI MPRIS player controller.")
    (license gpl3+)))

tmmpr
