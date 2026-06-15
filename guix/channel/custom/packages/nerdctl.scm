(define-module (custom packages nerdctl)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module ((guix licenses) #:prefix license:))

(define-public nerdctl
  (package
    (name "nerdctl")
    (version "2.3.1")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "https://github.com/containerd/nerdctl/releases/download/v"
                    version "/nerdctl-" version "-linux-amd64.tar.gz"))
              (sha256
               (base32 "0mjgssxya1s5j8kkb6qqsv2fxadcbbvvjg7s7mgl9zjfiydl14yj"))))
    (build-system gnu-build-system)
    (arguments
     '(#:tests? #f #:strip-binaries? #f #:validate-runpath? #f
       #:phases (modify-phases %standard-phases
                  (delete 'bootstrap) (delete 'configure)
                  (delete 'check) (delete 'build)
                  (delete 'patch-usr-bin-file)
                  (delete 'patch-source-shebangs)
                  (delete 'patch-generated-file-shebangs)
                  (replace 'install
                    (lambda* (#:key outputs #:allow-other-keys)
                      (let* ((out (assoc-ref outputs "out"))
                             (bdir (string-append out "/bin")))
                        (mkdir-p bdir)
                        (copy-file "nerdctl" (string-append bdir "/nerdctl"))
                        (chmod (string-append bdir "/nerdctl") #o555)))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/containerd/nerdctl")
    (synopsis "Docker-compatible CLI for containerd")
    (description "nerdctl is a Docker-compatible CLI for containerd.")
    (license license:asl2.0)))

nerdctl
