(define-module (custom packages pup)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages elf))

(define-public pup
  (package
    (name "pup")
    (version "0.4.0")
    (source
     (origin
       (method url-fetch)
       (uri
        "https://github.com/ericchiang/pup/releases/download/v0.4.0/pup_v0.4.0_linux_amd64.zip")
       (sha256
        (base32 "07503g3ym0mmqvs7zawxnk0b115ysrm592rc96n8fnrpzgljjggc"))))
    (build-system gnu-build-system)
    (native-inputs (list patchelf unzip))
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
                        (if (file-exists? "pup")
                            (begin
                              (install-file "pup" bdir)
                              (chmod (string-append bdir "/pup") #o555)
                              (false-if-exception (invoke pe
                                                          "--set-interpreter"
                                                          interp
                                                          (string-append bdir
                                                           "/pup"))))
                            (let ((files (find-files "."
                                                     (lambda (f s)
                                                       (string-contains (basename
                                                                         f)
                                                                        "pup")))))
                              (if (pair? files)
                                  (let ((src (car files)))
                                    (copy-file src
                                               (string-append bdir "/pup"))
                                    (chmod (string-append bdir "/pup") #o555)
                                    (false-if-exception (invoke pe
                                                         "--set-interpreter"
                                                         interp
                                                         (string-append bdir
                                                          "/pup"))))))) #t))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/ericchiang/pup")
    (synopsis "Command-line HTML parser")
    (description
     "pup is a command line tool for processing HTML using CSS selectors, inspired by jq.")
    (license expat)))

pup
