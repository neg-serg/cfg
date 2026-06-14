(define-module (custom packages kmon)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses)
  #:use-module (gnu packages base)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages elf))

(define-public kmon
  (package
    (name "kmon")
    (version "1.7.1")
    (source
     (origin
       (method url-fetch)
       (uri
        "https://github.com/orhun/kmon/releases/download/v1.7.1/kmon-1.7.1-x86_64-unknown-linux-gnu.tar.gz")
       (sha256
        (base32 "1d7sgzjxap4s01x6i8fz249hqlycavrdimfw2nwr0gbssmc4i6z3"))))
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
                      (let* ((out (assoc-ref outputs "out"))
                             (bdir (string-append out "/bin"))
                             (glibc (assoc-ref %build-inputs "libc"))
                             (interp (string-append glibc
                                      "/lib/ld-linux-x86-64.so.2"))
                             (pe (string-append (assoc-ref %build-inputs
                                                           "patchelf")
                                                "/bin/patchelf")))
                        (mkdir-p bdir)
                        (if (file-exists? "kmon")
                            (begin
                              (install-file "kmon" bdir)
                              (chmod (string-append bdir "/kmon") #o555)
                              (false-if-exception (invoke pe
                                                          "--set-interpreter"
                                                          interp
                                                          (string-append bdir
                                                           "/kmon"))))
                            (let ((files (find-files "."
                                                     (lambda (f s)
                                                       (string-contains (basename
                                                                         f)
                                                        "kmon")))))
                              (if (pair? files)
                                  (let ((src (car files)))
                                    (copy-file src
                                               (string-append bdir "/kmon"))
                                    (chmod (string-append bdir "/kmon") #o555)
                                    (false-if-exception (invoke pe
                                                         "--set-interpreter"
                                                         interp
                                                         (string-append bdir
                                                          "/kmon"))))))) #t))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/orhun/kmon")
    (synopsis "Linux Kernel Manager and Activity Monitor")
    (description
     "kmon provides a TUI for managing Linux kernel modules and monitoring kernel activity.")
    (license gpl3+)))

kmon
