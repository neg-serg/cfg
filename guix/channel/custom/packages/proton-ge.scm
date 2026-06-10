(define-module (custom packages proton-ge)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses)
  #:use-module (gnu packages base)
  #:use-module (gnu packages compression))
(define-public proton-ge-custom
  (package
    (name "proton-ge-custom")
    (version "GE-Proton10-34")
    (source (origin
              (method url-fetch)
              (uri "https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton10-34/GE-Proton10-34.tar.gz")
              (sha256 (base32 "0gbpipk3x7hqslp2y2h4aiv1jmxcxqbhf3z0iycp6g43dav81iai"))))
    (build-system gnu-build-system)
    (arguments
     '(#:tests? #f #:strip-binaries? #f #:validate-runpath? #f
       #:phases (modify-phases %standard-phases
         (delete 'bootstrap) (delete 'configure) (delete 'check) (delete 'build)
         (delete 'patch-usr-bin-file) (delete 'patch-source-shebangs)
         (delete 'patch-generated-file-shebangs)
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (let* ((out (assoc-ref outputs "out"))
                    (target (string-append out "/share/proton-ge-custom")))
               (copy-recursively "." target)
               #t))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/GloriousEggroll/proton-ge-custom")
    (synopsis "Proton GE custom build")
    (description "Custom Proton build for Steam with additional patches.")
    (license bsd-3)))

proton-ge-custom
