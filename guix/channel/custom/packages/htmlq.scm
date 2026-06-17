(define-module (custom packages htmlq)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages elf)
  #:use-module (gnu packages base))

(define-public htmlq
  (package
    (name "htmlq")
    (version "0.4.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "https://github.com/mgdm/htmlq/releases/download/v"
                    version "/htmlq-x86_64-linux.tar.gz"))
              (sha256
               (base32 "0jn7gxq07122zm4pkk7bdbg5wac8zjsjxnkjyhc1zaimv3cwhqsg"))))
    (build-system gnu-build-system)
    (native-inputs (list patchelf))
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
                                               "/bin/patchelf")))
                        (mkdir-p bdir)
                        (copy-file "htmlq" (string-append bdir "/htmlq"))
                        (chmod (string-append bdir "/htmlq") #o755)
                        (invoke pe "--set-interpreter" interp
                                (string-append bdir "/htmlq"))))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/mgdm/htmlq")
    (synopsis "Like jq, but for HTML")
    (description "htmlq extracts content from HTML using CSS selectors.")
    (license license:expat)))

htmlq
