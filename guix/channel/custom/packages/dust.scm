(define-module (custom packages dust)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages elf)
  #:use-module (gnu packages gcc)
  #:use-module (gnu packages base))

(define-public dust
  (package
    (name "dust")
    (version "1.2.4")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "https://github.com/bootandy/dust/releases/download/v"
                    version "/dust-v" version "-x86_64-unknown-linux-gnu.tar.gz"))
              (sha256
               (base32 "0q0ialb6iq6sbs1n693py891184qprdq2lrqiipm7p6jp6zzsz3h"))))
    (build-system gnu-build-system)
    (native-inputs (list patchelf `(,gcc "lib")))
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
                             (src (car (find-files "." (lambda (f s)
                                                        (string-suffix? "/dust" f)))))
                             (glibc (assoc-ref %build-inputs "libc"))
                             (interp (string-append glibc
                                      "/lib/ld-linux-x86-64.so.2"))
                             (pe (string-append
                                  (assoc-ref %build-inputs "patchelf")
                                  "/bin/patchelf"))
                             (gcc-lib (assoc-ref %build-inputs "gcc")))
                        (mkdir-p bdir)
                        (copy-file src (string-append bdir "/dust"))
                        (chmod (string-append bdir "/dust") #o755)
                        (invoke pe "--set-interpreter" interp
                                (string-append bdir "/dust"))
                        (invoke pe "--set-rpath"
                                (string-append glibc "/lib:"
                                               gcc-lib "/lib")
                                (string-append bdir "/dust"))))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/bootandy/dust")
    (synopsis "More intuitive version of du")
    (description "dust is a more intuitive version of du written in Rust. It shows disk usage with a tree structure for the terminal.")
    (license license:asl2.0)))

dust
