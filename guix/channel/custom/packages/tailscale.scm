(define-module (custom packages tailscale)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses)
  #:use-module (gnu packages elf))

(define-public tailscale
  (package
    (name "tailscale")
    (version "1.98.2")
    (source
      (origin
        (method url-fetch)
        (uri (string-append "https://pkgs.tailscale.com/stable/tailscale_"
                            "1.98.2" "_amd64.tgz"))
        (sha256
          (base32
            "077vgq9rhgnqbgf3zhjra7xx30r5aaws3bmnqspxbgxyrvmgvhl5"))))
    (build-system gnu-build-system)
    (native-inputs (list patchelf))
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
             (let* ((out    (assoc-ref outputs "out"))
                    (bin    (string-append out "/bin"))
                    (glibc  (assoc-ref %build-inputs "libc"))
                    (interp (string-append glibc
                                    "/lib/ld-linux-x86-64.so.2"))
                    (pe     (string-append
                             (assoc-ref %build-inputs "patchelf")
                             "/bin/patchelf")))
               (mkdir-p bin)
               (install-file "tailscale" bin)
               (install-file "tailscaled" bin)
               (for-each (lambda (b)
                          (false-if-exception
                           (invoke pe "--set-interpreter" interp
                                   (string-append bin "/" b))))
                         '("tailscale" "tailscaled"))
               #t))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://tailscale.com")
    (synopsis "VPN mesh networking")
    (description "Tailscale VPN mesh networking client.")
    (license bsd-3)))

tailscale
