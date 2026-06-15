(define-module (custom packages sbctl)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses)
  #:use-module (gnu packages elf)
  #:use-module (gnu packages base)
  #:use-module (gnu packages compression))

(define-public sbctl
  (package
    (name "sbctl")
    (version "0.15.4")
    (source
      (origin
        (method url-fetch)
        (uri (string-append
               "https://github.com/Foxboron/sbctl/releases/download/"
               version "/sbctl-" version "-linux-amd64.tar.gz"))
        (sha256
          (base32
            "1iv2zny6i70mk0324y12v0z9p4wjblcisi16yj2qd9r5gdil1i2v"))))
    (build-system gnu-build-system)
    (native-inputs (list patchelf tar gzip))
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
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (let* ((out    (assoc-ref outputs "out"))
                    (bin    (string-append out "/bin"))
                    (glibc  (assoc-ref %build-inputs "libc"))
                    (interp (string-append glibc
                                    "/lib/ld-linux-x86-64.so.2"))
                    (pe     (string-append
                             (assoc-ref %build-inputs "patchelf")
                             "/bin/patchelf")))
               (mkdir-p bin)
               (install-file "sbctl" bin)
               (chmod (string-append bin "/sbctl") #o555)
               (false-if-exception
                (invoke pe "--set-interpreter" interp
                        (string-append bin "/sbctl")))
               #t))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/Foxboron/sbctl")
    (synopsis "Secure Boot key manager")
    (description "sbctl is a user-friendly secure boot key manager capable of
setting up secure boot, signing files, and managing keys.")
    (license expat)))

sbctl
