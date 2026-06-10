(define-module (custom packages albumdetails)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages mp3))

(define-public albumdetails
  (package
    (name "albumdetails")
    (version "0.1.0")
    (source (origin
              (method url-fetch)
              (uri "https://github.com/neg-serg/albumdetails/archive/refs/heads/master.tar.gz")
              (sha256 (base32 "153jk1qsb8s6p3yq076i544656al1aj89nggilnccrblzy3pgiiy"))))
    (build-system gnu-build-system)
    (native-inputs (list pkg-config))
    (inputs (list taglib))
    (arguments
     '(#:tests? #f
       #:phases (modify-phases %standard-phases
         (delete 'configure)
         (replace 'build
           (lambda _
             (substitute* "Makefile"
               (("-I/usr/include/taglib")
                (string-append "-I" (assoc-ref %build-inputs "taglib") "/include/taglib")))
             (invoke "make" "CC=gcc")))
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (let* ((out (assoc-ref outputs "out"))
                    (bin (string-append out "/bin")))
               (mkdir-p bin)
               (copy-file "albumdetails" (string-append bin "/albumdetails"))
               (chmod (string-append bin "/albumdetails") #o755))
             #t)))))
    (home-page "https://github.com/neg-serg/albumdetails")
    (synopsis "Music album details tool")
    (description "Display music album details from metadata.")
    (license gpl3+)))

albumdetails
