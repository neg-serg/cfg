(define-module (custom packages sidecar)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses))

(define-public sidecar
  (package
    (name "sidecar")
    (version "0.84.0")
    (source (origin
              (method url-fetch)
              (uri "https://github.com/marcus/sidecar/releases/download/v0.84.0/sidecar_0.84.0_linux_amd64.tar.gz")
              (sha256 (base32 "0w0z4sgnzqpvhrhmvrc7cbrvbvamwa888n6scvw0jv5fy2xlbyc2"))))
    (build-system gnu-build-system)
    (arguments
     '(#:tests? #f #:strip-binaries? #f #:validate-runpath? #f
       #:phases (modify-phases %standard-phases
                  (delete 'bootstrap) (delete 'configure) (delete 'check)
                  (delete 'build) (delete 'patch-usr-bin-file)
                  (delete 'patch-source-shebangs)
                  (delete 'patch-generated-file-shebangs)
                  (replace 'install
                    (lambda* (#:key outputs #:allow-other-keys)
                      (let* ((out (assoc-ref outputs "out"))
                             (bin (string-append out "/bin"))
                             (script (car (find-files "." "^sidecar$"))))
                        (mkdir-p bin)
                        (copy-file script (string-append bin "/sidecar"))
                        (chmod (string-append bin "/sidecar") #o555))
                      #t)))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/marcus/sidecar")
    (synopsis "AI agent tool for code assistance")
    (description "AI agent tool for code assistance by marcus/sidecar.")
    (license expat)))

sidecar
