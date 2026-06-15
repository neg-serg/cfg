(define-module (custom packages unflac)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix build-system gnu)
  #:use-module ((guix licenses) #:prefix license:))

(define-public unflac
  (package
    (name "unflac")
    (version "1.4")
    (source (local-file "unflac.bin" #:recursive? #f))
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
                              (copy-file "unflac.bin" (string-append bdir "/unflac"))
                              (chmod (string-append bdir "/unflac") #o555)))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://git.sr.ht/~ft/unflac")
    (synopsis "Fast frame-accurate audio image + cue sheet splitter")
    (description "unflac splits audio images using cue sheets. Pre-built static binary.")
    (license license:bsd-3)))

unflac
