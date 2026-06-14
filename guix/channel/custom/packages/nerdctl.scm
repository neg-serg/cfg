(define-module (custom packages nerdctl)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix build-system gnu)
  #:use-module ((guix licenses) #:prefix license:))

(define nerdctl-bin
  (local-file "/tmp/nerdctl" #:recursive? #f))

(define-public nerdctl
  (package
    (name "nerdctl")
    (version "2.3.1")
    (source nerdctl-bin)
    (build-system gnu-build-system)
    (arguments
     (list #:tests? #f #:strip-binaries? #f #:validate-runpath? #f
           #:phases #~(modify-phases %standard-phases
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
