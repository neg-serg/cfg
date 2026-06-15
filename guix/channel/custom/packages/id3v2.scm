(define-module (custom packages id3v2)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages mp3)
  #:use-module (gnu packages elf)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages gcc))

(define-public id3v2
  (package
    (name "id3v2")
    (version "0.1.12")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://sourceforge.net/projects/id3v2/files/id3v2/"
                                  version "/id3v2-" version ".tar.gz"))
              (sha256 (base32 "1gr22w8gar7zh5pyyvdy7cy26i47l57jp1l1nd60xfwx339zl1c1"))))
    (build-system gnu-build-system)
    (inputs (list id3lib zlib))
    (native-inputs (list patchelf))
    (arguments
     '(#:tests? #f #:validate-runpath? #f #:strip-binaries? #f
       #:phases (modify-phases %standard-phases
                  (delete 'bootstrap)
                  (delete 'configure)
                  (delete 'check)
                  (add-after 'unpack 'fix-makefile
                    (lambda _
                      (substitute* "Makefile"
                        (("\\$\\(LDFLAGS\\).*") "$(LDFLAGS) -lid3 -lz\n"))
                      #t))
                  (replace 'build
                    (lambda _
                      ;; Force recompile — source ships pre-compiled 32-bit binary
                      (invoke "make" "clean")
                      (invoke "make")
                      #t))
                  (replace 'install
                    (lambda* (#:key outputs inputs #:allow-other-keys)
                      (let* ((out (assoc-ref outputs "out"))
                             (bin (string-append out "/bin"))
                             (id3lib-lib (string-append (assoc-ref inputs "id3lib") "/lib"))
                             (zlib-lib (string-append (assoc-ref inputs "zlib") "/lib"))
                             (pe (string-append (assoc-ref inputs "patchelf") "/bin/patchelf")))
                        (mkdir-p bin)
                        (copy-file "id3v2" (string-append bin "/id3v2"))
                        (invoke pe "--set-rpath"
                                (string-append id3lib-lib ":" zlib-lib)
                                (string-append bin "/id3v2"))
                        (chmod (string-append bin "/id3v2") #o555)))))))
    (home-page "https://id3v2.sourceforge.net")
    (synopsis "Command-line id3v2 tag editor")
    (description "id3v2 adds/removes/modifies id3v2 tags.")
    (license license:gpl2+)))

id3v2
