(define-module (custom packages choose)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages elf)
  #:use-module (gnu packages base)
  #:use-module (gnu packages gcc))

(define-public choose
  (package
    (name "choose")
    (version "1.3.7")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "https://github.com/theryangeary/choose/releases/download/v"
                    version "/choose-x86_64-unknown-linux-gnu"))
              (sha256
               (base32 "0kkq8f24qwv9i7qf5sxvpmjz6j0x91fxn5pjkj3c6gg509pmyzlz"))))
    (build-system gnu-build-system)
    (native-inputs (list patchelf (list gcc "lib")))
    (arguments
     `(#:tests? #f #:strip-binaries? #f #:validate-runpath? #f
       #:phases (modify-phases %standard-phases
                  (delete 'bootstrap) (delete 'configure)
                  (delete 'check) (delete 'build)
                  (delete 'patch-usr-bin-file)
                  (delete 'patch-source-shebangs)
                  (delete 'patch-generated-file-shebangs)
                  (replace 'install
                    (lambda* (#:key outputs #:allow-other-keys)
                      (let* ((out (assoc-ref outputs "out"))
                             (bdir (string-append out "/bin"))
                             (glibc (assoc-ref %build-inputs "libc"))
                             (interp (string-append glibc
                                      "/lib/ld-linux-x86-64.so.2"))
                             (pe (string-append
                                  (assoc-ref %build-inputs "patchelf")
                                  "/bin/patchelf"))
                             (gcc-lib (assoc-ref %build-inputs "gcc")))
                        (mkdir-p bdir)
                        (let ((src (if (file-exists? "choose-x86_64-unknown-linux-gnu")
                                     "choose-x86_64-unknown-linux-gnu"
                                     (car (find-files "." (lambda (f s)
                                       (string-contains (basename f) "choose-x86_64")))))))
                          (copy-file src (string-append bdir "/choose"))
                          (chmod (string-append bdir "/choose") #o755)
                          (invoke pe "--set-interpreter" interp
                                  (string-append bdir "/choose"))
                          (invoke pe "--set-rpath"
                                  (string-append glibc "/lib:"
                                                  gcc-lib "/lib")
                                   (string-append bdir "/choose")))))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/theryangeary/choose")
    (synopsis "Human-friendly and fast alternative to cut/awk")
    (description "choose is a human-friendly and fast alternative to awk and cut. Select fields from stdin with a simple field syntax.")
    (license license:gpl3+)))

choose
