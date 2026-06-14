(define-module (custom packages go-yq)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages elf))

(define-public go-yq
  (package
    (name "go-yq")
    (version "4.47.1")
    (source
     (origin
       (method url-fetch)
       (uri
        "https://github.com/mikefarah/yq/releases/download/v4.47.1/yq_linux_amd64.tar.gz")
       (sha256
        (base32 "0kbzf06n2gs48kh93ximj53g0b9qa9wji7ay00r8xs5zv5qx90vm"))))
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
                        (if (file-exists? "yq_linux_amd64")
                            (begin
                              (copy-file "yq_linux_amd64"
                                         (string-append bdir "/yq"))
                              (chmod (string-append bdir "/yq") #o555)
                              (false-if-exception (invoke pe
                                                          "--set-interpreter"
                                                          interp
                                                          (string-append bdir
                                                           "/yq"))))
                            (let ((files (find-files "."
                                                     (lambda (f s)
                                                       (string-contains (basename
                                                                         f)
                                                                        "yq")))))
                              (if (pair? files)
                                  (let ((src (car files)))
                                    (copy-file src
                                               (string-append bdir "/yq"))
                                    (chmod (string-append bdir "/yq") #o555)
                                    (false-if-exception (invoke pe
                                                         "--set-interpreter"
                                                         interp
                                                         (string-append bdir
                                                                        "/yq")))))))
                        #t))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/mikefarah/yq")
    (synopsis "Portable YAML processor written in Go")
    (description
     "yq is a lightweight and portable command-line YAML, JSON and XML processor. It uses jq-like syntax.")
    (license expat)))

go-yq
