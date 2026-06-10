(define-module (custom packages kanata)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses)
  #:use-module (gnu packages compression))

(define-public kanata
  (package
    (name "kanata")
    (version "1.11.0")
    (source (origin
              (method url-fetch)
              (uri "https://github.com/jtroo/kanata/releases/download/v1.11.0/linux-binaries-x64.zip")
              (sha256 (base32 "1qmlb5a54hgri65c8v19hd6jshsvss7rkwxc5b67iw67njpk9xnr"))))
    (build-system gnu-build-system)
    (native-inputs (list unzip))
    (arguments
     '(#:tests? #f #:strip-binaries? #f #:validate-runpath? #f
       #:phases (modify-phases %standard-phases
                  (delete 'bootstrap) (delete 'configure) (delete 'check)
                  (delete 'build) (delete 'patch-usr-bin-file)
                  (delete 'patch-source-shebangs)
                  (delete 'patch-generated-file-shebangs)
                  (add-after 'unpack 'fix-perms
                    (lambda _
                      (for-each (lambda (f) (chmod f #o555))
                        (find-files "." "kanata.*"))
                      #t))
                  (replace 'install
                    (lambda* (#:key outputs #:allow-other-keys)
                      (let* ((out (assoc-ref outputs "out"))
                             (bin (string-append out "/bin")))
                        (mkdir-p bin)
                        (for-each (lambda (f)
                                    (copy-file f (string-append bin "/" (basename f))))
                                  (find-files "." "^kanata_")))
                      #t)))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/jtroo/kanata")
    (synopsis "Keyboard remapper with advanced customization")
    (description "Improve keyboard comfort and usability with advanced customization.")
    (license lgpl3+)))

kanata