(define-module (custom packages broot)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix build-system gnu)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages elf)
  #:use-module (gnu packages base)
  #:use-module (gnu packages gcc))

(define-public broot
  (package
    (name "broot")
    (version "1.44.0")
    (source (local-file "broot.bin" #:recursive? #f))
    (build-system gnu-build-system)
    (native-inputs (list patchelf))
    (inputs (list (list gcc "lib")))
    (arguments
     '(#:tests? #f #:strip-binaries? #f #:validate-runpath? #f
       #:phases (modify-phases %standard-phases
                  (delete 'bootstrap) (delete 'configure)
                  (delete 'check) (delete 'build)
                  (delete 'patch-usr-bin-file)
                  (delete 'patch-source-shebangs)
                  (delete 'patch-generated-file-shebangs)
                  (replace 'install
                    (lambda* (#:key outputs inputs #:allow-other-keys)
                      (let* ((out (assoc-ref outputs "out"))
                             (bdir (string-append out "/bin"))
                             (glibc (assoc-ref %build-inputs "libc"))
                             (interp (string-append glibc
                                      "/lib/ld-linux-x86-64.so.2"))
                             (pe (string-append (assoc-ref inputs "patchelf")
                                               "/bin/patchelf"))
                             (gcc-lib (assoc-ref inputs "gcc")))
                        (mkdir-p bdir)
                        (copy-file "broot.bin" (string-append bdir "/broot"))
                        (chmod (string-append bdir "/broot") #o755)
                        (invoke pe "--set-interpreter" interp
                                "--set-rpath" (string-append gcc-lib "/lib")
                                (string-append bdir "/broot"))
                        (chmod (string-append bdir "/broot") #o555)))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/Canop/broot")
    (synopsis "Tree-based file explorer")
    (description "broot is a terminal file manager and explorer.")
    (license license:expat)))

broot
