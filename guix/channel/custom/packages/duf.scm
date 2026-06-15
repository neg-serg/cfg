(define-module (custom packages duf)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module ((guix licenses) #:prefix license:))

(define-public duf
  (package
    (name "duf")
    (version "0.9.1")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "https://github.com/muesli/duf/releases/download/v"
                    version "/duf_" version "_linux_x86_64.tar.gz"))
              (sha256
               (base32 "1rrdhd9z2l8xyfpr15180qnzl52dbrq69dmb75lybib2f0g8bpas"))))
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
                        (copy-file "duf" (string-append bdir "/duf"))
                        (chmod (string-append bdir "/duf") #o555)))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/muesli/duf")
    (synopsis "Disk Usage/Free Utility")
    (description "duf is a simple disk usage/free utility with a terminal UI supporting Linux, BSD, macOS, and Windows.")
    (license license:expat)))

duf
