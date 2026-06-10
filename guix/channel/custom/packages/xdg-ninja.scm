(define-module (custom packages xdg-ninja)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses))

(define-public xdg-ninja
  (package
    (name "xdg-ninja")
    (version "0.2.0.2")
    (source (origin
              (method url-fetch)
              (uri "https://github.com/b3nj5m1n/xdg-ninja/releases/download/v0.2.0.2/xdgnj")
              (sha256 (base32 "0yz62dmgygnacybkw9llak5fcazj5z5q04bbhfr10vhnljl54l6b"))))
    (build-system gnu-build-system)
    (arguments
     '(#:tests? #f #:strip-binaries? #f #:validate-runpath? #f #:patch-shebangs? #f
       #:phases (modify-phases %standard-phases
         (delete 'bootstrap) (delete 'configure) (delete 'check)
         (delete 'build)
         (delete 'patch-usr-bin-file) (delete 'patch-source-shebangs)
         (delete 'patch-generated-file-shebangs)
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (let* ((out (assoc-ref outputs "out"))
                    (bin (string-append out "/bin"))
                    (script (car (find-files "." "^xdgnj$"))))
               (mkdir-p bin)
               (copy-file script (string-append bin "/xdgnj"))
               (chmod (string-append bin "/xdgnj") #o555))
             #t)))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/b3nj5m1n/xdg-ninja")
    (synopsis "Check your XDG base directory compliance")
    (description "xdg-ninja checks your home directory for files that should be in XDG base directories.")
    (license expat)))

xdg-ninja