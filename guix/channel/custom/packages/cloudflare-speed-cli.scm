(define-module (custom packages cloudflare-speed-cli)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module ((guix licenses) #:prefix license:))

(define-public cloudflare-speed-cli
  (package
    (name "cloudflare-speed-cli")
    (version "1.0.5")
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "https://github.com/kavehtehrani/cloudflare-speed-cli/releases/download/v"
             version "/cloudflare-speed-cli-x86_64-unknown-linux-musl.tar.xz"))
       (sha256
        (base32 "1c0wrb7p9jl533z35ykwbscgs29f7f0zv3hmndxvra0v467y3831"))))
    (build-system gnu-build-system)
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
                      (let ((out (assoc-ref outputs "out"))
                            (bin (string-append (assoc-ref outputs "out") "/bin")))
                        (mkdir-p bin)
                        (copy-file "cloudflare-speed-cli"
                                   (string-append bin "/cloudflare-speed-cli"))
                        (chmod (string-append bin "/cloudflare-speed-cli") #o555)))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/kavehtehrani/cloudflare-speed-cli")
    (synopsis "CLI internet speed test via Cloudflare")
    (description "A command-line tool for testing internet speed using
Cloudflare's speed test infrastructure.  Supports download/upload bandwidth
measurement and latency testing.")
    (license license:expat)))

cloudflare-speed-cli
