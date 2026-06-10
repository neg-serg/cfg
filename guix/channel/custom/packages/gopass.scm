(define-module (custom packages gopass)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses)
  #:use-module (gnu packages elf))

(define-public gopass
  (package
    (name "gopass")
    (version "1.16.1")
    (source
      (origin
        (method url-fetch)
        (uri (string-append
               "https://github.com/gopasspw/gopass/releases/download/v"
               "1.16.1" "/gopass-1.16.1-linux-amd64.tar.gz"))
        (sha256
          (base32
            "1dqf1jmpg6y6wcg74s6k65i3agscq07khmbihkxys729ljdk0xxy"))))
    (build-system gnu-build-system)
    (native-inputs (list patchelf))
    (arguments
     '(#:tests? #f
       #:strip-binaries? #f
       #:validate-runpath? #f
       #:phases (modify-phases %standard-phases
         (delete 'configure)
         (delete 'check)
         (delete 'build)
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (let* ((out (assoc-ref outputs "out"))
                    (bin (string-append out "/bin"))
                    (glibc (assoc-ref %build-inputs "libc"))
                    (interp (string-append glibc "/lib/ld-linux-x86-64.so.2"))
                    (pe (string-append (assoc-ref %build-inputs "patchelf")
                                       "/bin/patchelf")))
               (mkdir-p bin)
               (install-file "gopass" bin)
               (invoke pe "--set-interpreter" interp
                       (string-append bin "/gopass"))
               #t))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://www.gopass.pw")
    (synopsis "Password manager for teams")
    (description "Gopass is a password manager for the command line.")
    (license expat)))

gopass
