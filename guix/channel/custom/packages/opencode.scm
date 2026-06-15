(define-module (custom packages opencode)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module ((guix licenses) #:prefix license:))

(define-public opencode
  (package
    (name "opencode")
    (version "1.17.7")
    (source
      (origin
        (method url-fetch)
        (uri (string-append
               "https://github.com/anomalyco/opencode/releases/download/v"
               version "/opencode-linux-x64.tar.gz"))
        (sha256
          (base32 "093rc20880z87csyirzgcylacbg12zgfv3rlg704xxlsvj95mzk0"))))
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
                      (let* ((out (assoc-ref outputs "out"))
                             (bdir (string-append out "/bin")))
                        (mkdir-p bdir)
                        (copy-file "opencode"
                                   (string-append bdir "/opencode"))
                        (chmod (string-append bdir "/opencode") #o555)))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/anomalyco/opencode")
    (synopsis "The AI coding agent built for the terminal")
    (description "OpenCode is a terminal-based AI coding agent
that helps with software engineering tasks.")
    (license license:expat)))

opencode
