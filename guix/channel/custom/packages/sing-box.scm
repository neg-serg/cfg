(define-module (custom packages sing-box)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses)
  #:use-module (gnu packages elf))

(define-public sing-box
  (package
    (name "sing-box")
    (version "1.13.12")
    (source
      (origin
        (method url-fetch)
        (uri (string-append
               "https://github.com/SagerNet/sing-box/releases/download/v"
               "1.13.12" "/sing-box-1.13.12-linux-amd64.tar.gz"))
        (sha256
          (base32
            "1i66gsjavp6aiwkyphd120dl1hnvldy5qjzismd4zwixvcx56h0m"))))
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
             (let* ((out  (assoc-ref outputs "out"))
                    (bin  (string-append out "/bin"))
                    (glibc (assoc-ref %build-inputs "libc"))
                    (interp (string-append glibc "/lib/ld-linux-x86-64.so.2"))
                    (pe (string-append (assoc-ref %build-inputs "patchelf")
                                       "/bin/patchelf")))
               (mkdir-p bin)
               (install-file "sing-box" bin)
               (invoke pe "--set-interpreter" interp
                       (string-append bin "/sing-box"))
               #t))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/SagerNet/sing-box")
    (synopsis "Universal proxy platform")
    (description "Universal proxy platform for VPN and proxy services.")
    (license gpl3+)))

sing-box
