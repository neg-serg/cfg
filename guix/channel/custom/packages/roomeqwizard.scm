(define-module (custom packages roomeqwizard)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses))

(define-public roomeqwizard
  (let ((installer (local-file "roomeqwizard.sh")))
    (package
      (name "roomeqwizard")
      (version "5.31.3")
      (source installer)
      (build-system gnu-build-system)
      (arguments
       `(#:tests? #f #:strip-binaries? #f #:validate-runpath? #f
         #:phases (modify-phases %standard-phases
           (delete (quote bootstrap)) (delete (quote configure)) (delete (quote check))
           (delete (quote build))
           (delete (quote patch-usr-bin-file)) (delete (quote patch-source-shebangs))
           (delete (quote patch-generated-file-shebangs))
           (replace (quote unpack)
             (lambda* (#:key source #:allow-other-keys)
               (symlink source "roomeqwizard.sh")
               #t))
           (replace (quote install)
             (lambda* (#:key outputs #:allow-other-keys)
               (let* ((out (assoc-ref outputs "out"))
                      (bin (string-append out "/bin")))
                 (mkdir-p bin)
                 (copy-file "roomeqwizard.sh" (string-append bin "/roomeqwizard"))
                 (chmod (string-append bin "/roomeqwizard") #o555))
               #t)))))
      (home-page "https://www.roomeqwizard.com")
      (synopsis "Room acoustics software")
      (description "Room EQ Wizard room acoustics software.")
      (license gpl3+))))

roomeqwizard
