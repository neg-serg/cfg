(define-module (custom packages proton-cachyos)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses)
  #:use-module (gnu packages compression))

(define-public proton-cachyos
  (package
    (name "proton-cachyos")
    (version "11.0-20260601")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "https://github.com/CachyOS/proton-cachyos/releases/download/"
                    "cachyos-11.0-20260601-slr/"
                    "proton-cachyos-11.0-20260601-slr-x86_64.tar.xz"))
               ;; FIXME: large file (~900 MB), run `guix build -f proton-cachyos.scm` to fill hash
               (sha256 (base32 "0000000000000000000000000000000000000000000000000000"))))
    (build-system gnu-build-system)
    (native-inputs (list xz))
    (arguments
     '(#:tests? #f #:strip-binaries? #f #:validate-runpath? #f
       #:phases (modify-phases %standard-phases
         (delete 'bootstrap) (delete 'configure) (delete 'check) (delete 'build)
         (delete 'patch-usr-bin-file) (delete 'patch-source-shebangs)
         (delete 'patch-generated-file-shebangs)
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (let* ((out (assoc-ref outputs "out"))
                    (target (string-append out "/share/proton-cachyos")))
               (copy-recursively "." target)
               #t))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/CachyOS/proton-cachyos")
    (synopsis "CachyOS-optimized Proton build")
    (description "Custom Proton build for Steam with CachyOS optimizations
and additional patches.")
    (license bsd-3)))

proton-cachyos
