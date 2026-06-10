(define-module (custom packages bazecor)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses)
  #:use-module (gnu packages elf))

(define-public bazecor
  (package
    (name "bazecor")
    (version "1.8.3")
    (source (origin
              (method url-fetch)
              (uri "https://github.com/Dygmalab/Bazecor/releases/download/v1.8.3/Bazecor-1.8.3-x64.AppImage")
              (sha256 (base32 "15v0g1wh7pknc5i9nrpa5cfanf1r0bilpcgc55jy2nyvn9w0f31q"))))
    (build-system gnu-build-system)
    (native-inputs (list patchelf))
    (arguments
     '(#:tests? #f #:strip-binaries? #f #:validate-runpath? #f
       #:phases (modify-phases %standard-phases
         (delete 'bootstrap) (delete 'configure) (delete 'check)
         (delete 'build) (delete 'patch-usr-bin-file)
         (delete 'patch-source-shebangs) (delete 'patch-generated-file-shebangs)
         (replace 'unpack
           (lambda* (#:key source #:allow-other-keys)
             (copy-file source "bazecor")
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
               (install-file "bazecor" bin)
               (chmod (string-append bin "/bazecor") #o555)
               (false-if-exception
                (invoke pe "--set-interpreter" interp
                        (string-append bin "/bazecor")))
               #t))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://www.dygma.com/bazecor")
    (synopsis "Keyboard configurator for Dygma Raise")
    (description "Keyboard configuration tool for Dygma Raise keyboards.")
    (license gpl3+)))

bazecor
