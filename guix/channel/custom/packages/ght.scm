(define-module (custom packages ght)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses)
  #:use-module (gnu packages elf))

(define-public ght
  (package
    (name "ght")
    (version "0.1.0")
    (source (origin
              (method url-fetch)
              (uri "https://github.com/kwame-Owusu/ght/releases/download/v0.1.0/ght-linux-amd64")
              (sha256 (base32 "03zh1hncyr5lf3li84kg1abr3hvi2r45xg86srvjgwwrywvf6xyb"))))
    (build-system gnu-build-system)
    (native-inputs (list patchelf))
    (arguments
     '(#:tests? #f #:strip-binaries? #f #:validate-runpath? #f
       #:phases (modify-phases %standard-phases
         (delete 'bootstrap) (delete 'configure) (delete 'check) (delete 'build)
         (delete 'patch-usr-bin-file) (delete 'patch-source-shebangs)
         (delete 'patch-generated-file-shebangs)
         (replace 'unpack
           (lambda* (#:key source #:allow-other-keys)
             (symlink source "ght-linux-amd64")
             #t))
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (let* ((out   (assoc-ref outputs "out"))
                    (bin   (string-append out "/bin"))
                    (glibc (assoc-ref %build-inputs "libc"))
                    (interp (string-append glibc "/lib/ld-linux-x86-64.so.2"))
                    (pe    (string-append (assoc-ref %build-inputs "patchelf")
                                          "/bin/patchelf")))
               (mkdir-p bin)
               (install-file "ght-linux-amd64" bin)
               (rename-file (string-append bin "/ght-linux-amd64")
                            (string-append bin "/ght"))
               (chmod (string-append bin "/ght") #o755)
               (invoke pe "--set-interpreter" interp
                       (string-append bin "/ght"))
               #t))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/kwame-Owusu/ght")
    (synopsis "GitHub CLI tool")
    (description "GitHub CLI tool.")
    (license gpl3+)))

ght
