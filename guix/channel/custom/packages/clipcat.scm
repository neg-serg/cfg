(define-module (custom packages clipcat)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses))

(define-public clipcat
  (package
    (name "clipcat")
    (version "0.25.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "https://github.com/xrelkd/clipcat/releases/"
                    "download/v" version "/clipcat-" version
                    "-x86_64-unknown-linux-musl.tar.gz"))
              (sha256
               (base32
                "09kpiggwj2cwrqh6pxh1kknax3rjqvy9czqw60pnarlimyvq24if"))))
    (build-system gnu-build-system)
    (arguments
     '(#:tests? #f
       #:phases (modify-phases %standard-phases
         (delete 'bootstrap)
         (delete 'configure)
         (delete 'check)
         (delete 'build)
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (let* ((out (assoc-ref outputs "out"))
                    (bin (string-append out "/bin")))
               (mkdir-p bin)
               (for-each (lambda (f)
                           (install-file f bin))
                         (find-files "." "^clipcat"))
               #t))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/xrelkd/clipcat")
    (synopsis "Clipboard manager written in Rust")
    (description "Clipcat is a clipboard manager that monitors the
system clipboard and provides a history of copied items.")
    (license gpl3+)))

clipcat
