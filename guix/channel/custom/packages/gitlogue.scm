(define-module (custom packages gitlogue)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix build-system gnu)
  #:use-module ((guix licenses) #:prefix license:))

(define-public gitlogue
  (package
    (name "gitlogue")
    (version "0.9.0")
    (source (local-file "/gnu/store/2nrvmv44m49w2m7bsz1bcy7lgfz8ffsr-gitlogue-0.9.0/bin/gitlogue" #:recursive? #f))
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
                        (copy-file "gitlogue" (string-append bdir "/gitlogue"))
                        (chmod (string-append bdir "/gitlogue") #o555)))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/ankitects/gitlogue")
    (synopsis "Interactive Git history browser")
    (description "gitlogue provides an interactive Git history browser.")
    (license license:expat)))

gitlogue
