;;; custom/packages/libjodycode.scm — utility library for file wrangling tools
(define-module (custom packages libjodycode)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses))

(define-public libjodycode
  (package
    (name "libjodycode")
    (version "4.1.2")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://codeberg.org/jbruchon/libjodycode")
             (commit (string-append "v" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "1bi4w76svmfgyaja3mpkzfd71nzyrm78yvpdkvayc38nkinwv80y"))))
    (build-system gnu-build-system)
    (arguments
     '(#:tests? #f
       #:make-flags (list (string-append "PREFIX=" %output)
                          "CC=gcc")
       #:phases (modify-phases %standard-phases
                  (delete 'configure))))
    (home-page "https://codeberg.org/jbruchon/libjodycode")
    (synopsis "Utility library used by jwack, jdupes, and other tools")
    (description
     "Libjodycode is a small utility library that provides common
functionality used by several file-wrangling tools including jwack
and jdupes.  It handles filesystem operations, hashing, CRC
calculations, memory management, and other low-level tasks.")
    (license expat)))

libjodycode
