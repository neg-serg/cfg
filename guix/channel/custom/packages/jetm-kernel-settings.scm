(define-module (custom packages jetm-kernel-settings)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses))

(define-public jetm-kernel-settings
  (package
    (name "jetm-kernel-settings")
    (version "1.0.0")
    (source (origin
              (method url-fetch)
              (uri "https://aur.archlinux.org/cgit/aur.git/snapshot/jetm-kernel-settings.tar.gz")
              (sha256 (base32 "0ddysnh0yrxh7db0096jlxhxgh6s3f1mz7kd6x9qmwga9bnd9la6"))))
    (build-system gnu-build-system)
    (arguments
     `(#:tests? #f #:strip-binaries? #f #:validate-runpath? #f
       #:phases (modify-phases %standard-phases
         (delete 'configure) (delete 'check) (delete 'build)
         (delete 'bootstrap) (delete 'patch-source-shebangs)
         (delete 'patch-generated-file-shebangs)
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (let ((out (assoc-ref outputs "out")))
               (copy-recursively "." out))
              #t)))))
    (home-page "")
    (synopsis "Kernel tuning configs")
    (description "System tuning configs for Ryzen/mixed-storage.")
    (license gpl3+)))

jetm-kernel-settings
