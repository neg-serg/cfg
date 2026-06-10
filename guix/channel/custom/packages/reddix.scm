(define-module (custom packages reddix)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses))

(define-public reddix
  (package
    (name "reddix")
    (version "0.2.9")
    (source
      (origin
        (method url-fetch)
        (uri (string-append
               "https://github.com/ck-zhang/reddix/releases/download/v"
               version "/reddix-x86_64-unknown-linux-gnu.tar.xz"))
        (sha256
          (base32
            "00cj2w9x8qa8f3cnhbakp4g1rqg12anrlz0c3gafggr9czz9a4ax"))))
    (build-system gnu-build-system)
    (arguments
     '(#:tests? #f #:strip-binaries? #f
       #:phases (modify-phases %standard-phases
         (delete 'bootstrap) (delete 'configure) (delete 'check) (delete 'build)
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (let* ((out (assoc-ref outputs "out"))
                    (bin (string-append out "/bin")))
               (mkdir-p bin)
               (chdir "reddix-x86_64-unknown-linux-gnu")
               (install-file "reddix" bin)
               #t))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/ck-zhang/reddix")
    (synopsis "Reddix — Reddit client (Rust)")
    (description "Lightweight Reddit client for the terminal.")
    (license expat)))

reddix
