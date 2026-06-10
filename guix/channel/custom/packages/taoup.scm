(define-module (custom packages taoup)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses))

(define-public taoup
  (package
    (name "taoup")
    (version "1.1.24")
    (source (origin
              (method url-fetch)
              (uri "https://github.com/globalcitizen/taoup/archive/refs/tags/v1.1.24.tar.gz")
              (sha256 (base32 "0f251hx75dr4abzig59px4ci0arpykww2rbga8whwhjp7ls6k5cy"))))
    (build-system gnu-build-system)
    (arguments
     '(#:tests? #f #:strip-binaries? #f #:validate-runpath? #f #:patch-shebangs? #f
       #:phases (modify-phases %standard-phases
                  (delete 'bootstrap) (delete 'configure) (delete 'check)
                  (delete 'build) (delete 'patch-usr-bin-file)
                  (delete 'patch-source-shebangs)
                  (delete 'patch-generated-file-shebangs)
                  (replace 'install
                    (lambda* (#:key outputs #:allow-other-keys)
                      (let* ((out (assoc-ref outputs "out"))
                             (bin (string-append out "/bin"))
                             (script (car (find-files "." "^taoup$"))))
                        (mkdir-p bin)
                        (copy-file script (string-append bin "/taoup"))
                        (chmod (string-append bin "/taoup") #o555))
                      #t)))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/globalcitizen/taoup")
    (synopsis "The Tao of Unix Programming fortunes")
    (description "Tao of Unix Programming fortunes.")
    (license expat)))

taoup
