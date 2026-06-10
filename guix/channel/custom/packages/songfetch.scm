(define-module (custom packages songfetch)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses))

(define-public songfetch
  (package
    (name "songfetch")
    (version "1.0.3")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://github.com/ekrlstd/songfetch/archive/refs/tags/v" version ".tar.gz"))
              (sha256 (base32 "0a482k5yks272y0dfjfyajnf31aq7lp9blxm3qlaj5la7gqkms0x"))))
    (build-system gnu-build-system)
    (arguments
     `(#:tests? #f #:strip-binaries? #f #:validate-runpath? #f
       #:phases (modify-phases %standard-phases
         (delete 'bootstrap) (delete 'configure) (delete 'check) (delete 'build)
         (delete 'patch-usr-bin-file) (delete 'patch-source-shebangs)
         (delete 'patch-generated-file-shebangs)
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (let* ((out (assoc-ref outputs "out"))
                    (bin (string-append out "/bin"))
                    (script (find-files "." "songfetch")))
               (mkdir-p bin)
               (if (pair? script)
                   (begin
                     (copy-file (car script) (string-append bin "/songfetch"))
                     (chmod (string-append bin "/songfetch") #o555)))
               #t))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/ekrlstd/songfetch")
    (synopsis "Fetch song info")
    (description "Display currently playing song information.")
    (license gpl3+)))

songfetch
