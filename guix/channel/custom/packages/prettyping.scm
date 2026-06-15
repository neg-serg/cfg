(define-module (custom packages prettyping)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module (guix build-system gnu)
  #:use-module ((guix licenses) #:prefix license:))

(define-public prettyping
  (package
    (name "prettyping")
    (version "1.0.1")
    (source (origin
              (method git-fetch)
              (uri (git-reference
                    (url "https://github.com/denilsonsa/prettyping")
                    (commit (string-append "v" version))))
              (file-name (git-file-name name version))
              (sha256 (base32 "05vfaq9y52z40245j47yjk1xaiwrazv15sgjq64w91dfyahjffxf"))))
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
                             (bin (string-append out "/bin")))
                        (mkdir-p bin)
                        (copy-file "prettyping" (string-append bin "/prettyping"))
                        (chmod (string-append bin "/prettyping") #o555)))))))
    (home-page "https://github.com/denilsonsa/prettyping")
    (synopsis "Ping wrapper with colored output")
    (description "prettyping is a wrapper around standard ping to make output prettier.")
    (license license:expat)))

prettyping
