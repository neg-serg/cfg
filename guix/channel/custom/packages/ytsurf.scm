(define-module (custom packages ytsurf)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses))

(define-public ytsurf
  (package
    (name "ytsurf")
    (version "3.1.7")
    (source (origin
              (method url-fetch)
              (uri "https://github.com/Stan-breaks/ytsurf/archive/refs/tags/v3.1.7.tar.gz")
              (sha256 (base32 "08hfpgk9afz586hn1nwln8msl8i59ip41j6y60q8533lqsgyhqds"))))
    (build-system gnu-build-system)
    (arguments
     '(#:tests? #f #:strip-binaries? #f #:validate-runpath? #f
       #:phases (modify-phases %standard-phases
         (delete 'bootstrap) (delete 'configure) (delete 'check)
         (delete 'build)
         (delete 'patch-usr-bin-file) (delete 'patch-source-shebangs)
         (delete 'patch-generated-file-shebangs)
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (let* ((out (assoc-ref outputs "out"))
                    (bin (string-append out "/bin"))
                    (script (car (find-files "." "ytsurf\\.sh"))))
               (mkdir-p bin)
               (copy-file script (string-append bin "/ytsurf"))
               (chmod (string-append bin "/ytsurf") #o555))
             #t)))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/Stan-breaks/ytsurf")
    (synopsis "YouTube TUI")
    (description "YouTube in your terminal. Clean and distraction-free.")
    (license gpl3+)))

ytsurf
