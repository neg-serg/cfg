(define-module (custom packages par)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses))

(define-public par
  (package
    (name "par")
    (version "1.53")
    (source (origin
              (method url-fetch)
              (uri "http://www.nicemice.net/par/Par-1.53.0.tar.gz")
              (sha256 (base32 "013qqi5f8avg0hyd2f934rnijmfsr2c9hjy579aqkdc2xchcc2f8"))))
    (build-system gnu-build-system)
    (arguments
     '(#:tests? #f
       #:phases (modify-phases %standard-phases
         (delete 'configure)
         (replace 'build
           (lambda* (#:key #:allow-other-keys)
             (invoke "make" "-f" "protoMakefile"
                     "CC=gcc -std=c99 -D_GNU_SOURCE -c"
                     "LINK1=gcc")
             #t))
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (let* ((out (assoc-ref outputs "out"))
                    (bin (string-append out "/bin")))
               (mkdir-p bin)
               (install-file "par" bin))
             #t)))))
    (home-page "http://www.nicemice.net/par/")
    (synopsis "Paragraph reformatter")
    (description "Paragraph reformatter for text files.")
    (license gpl2+)))

par
