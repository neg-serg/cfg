(define-module (custom packages bazecor)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system trivial)
  #:use-module (guix licenses))

(define-public bazecor
  (package
    (name "bazecor")
    (version "1.8.3")
    (source (origin
              (method url-fetch)
              (uri "https://github.com/Dygmalab/Bazecor/releases/download/v1.8.3/Bazecor-1.8.3-x64.AppImage")
              (sha256 (base32 "15v0g1wh7pknc5i9nrpa5cfanf1r0bilpcgc55jy2nyvn9w0f31q"))))
    (build-system trivial-build-system)
    (arguments
     '(#:modules ((guix build utils))
       #:builder
       (begin
         (use-modules (guix build utils))
         (let* ((source (assoc-ref %build-inputs "source"))
                (out    (assoc-ref %outputs "out"))
                (bin   (string-append out "/bin")))
           (mkdir-p bin)
           (copy-file source (string-append bin "/bazecor"))
           (chmod (string-append bin "/bazecor") #o555)))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://www.dygma.com/bazecor")
    (synopsis "Keyboard configurator for Dygma Raise")
    (description "Keyboard configuration tool for Dygma Raise keyboards.")
    (license gpl3+)))

bazecor
