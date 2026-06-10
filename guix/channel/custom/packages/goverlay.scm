(define-module (custom packages goverlay)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses))

(define-public goverlay
  (package
    (name "goverlay")
    (version "1.8.1")
    (source
      (origin
        (method url-fetch)
        (uri (string-append
               "https://github.com/benjamimgois/goverlay/releases/download/"
               version "/goverlay_1_8_1.tar.xz"))
        (sha256
          (base32 "1smqvn2h35xhy92dfhnzj3l0c09nq9yig2whsmjd9c5p9gsv54s4"))))
    (build-system gnu-build-system)
    (home-page "https://github.com/benjamimgois/goverlay")
    (synopsis "MangoHud configuration GUI")
    (description "Goverlay is a GUI for configuring MangoHud.")
    (license gpl3+)
    (arguments
     '(#:tests? #f
       #:validate-runpath? #f
       #:phases (modify-phases %standard-phases
         (delete 'bootstrap)
         (delete 'configure)
         (delete 'check)
         (delete 'build)
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (let ((out (assoc-ref outputs "out")))
               (mkdir-p (string-append out "/bin"))
               (install-file "goverlay" (string-append out "/bin"))
               #t))))))))

goverlay
