(define-module (custom packages limine)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses))

(define-public limine
  (package
    (name "limine")
    (version "12.3.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "https://github.com/limine-bootloader/limine/"
                    "releases/download/v" version
                    "/limine-binary.tar.xz"))
              (sha256
               (base32
                "1b07zvps0axks2wygvpa00bxfj81qxr1bz4vqcf64pjrf851xqb7"))))
    (build-system gnu-build-system)
    (arguments
     '(#:tests? #f
       #:make-flags '("CC=gcc")
       #:phases (modify-phases %standard-phases
         (delete 'bootstrap)
         (delete 'configure)
         (delete 'check)
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (let* ((out (assoc-ref outputs "out"))
                    (bin (string-append out "/bin"))
                    (share (string-append out "/share/limine")))
               (mkdir-p bin)
               (mkdir-p share)
               (install-file "limine" bin)
               (for-each (lambda (f)
                           (install-file f share))
                         (find-files "." "\\.(sys|bin|h|EFI|c|S)$"))
               (install-file "LICENSE" share)
               (install-file "Makefile" share)
               #t))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://limine-bootloader.org/")
    (synopsis "Advanced multiprotocol bootloader (pre-built)")
    (description "Limine is an advanced, portable, multiprotocol
bootloader.  This package provides pre-built bootloader payloads
and a compiled installer from the upstream binary release.")
    (license bsd-2)))

limine
