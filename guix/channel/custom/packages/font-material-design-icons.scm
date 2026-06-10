(define-module (custom packages font-material-design-icons)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses))

(define-public font-material-design-icons
  (package
    (name "font-material-design-icons")
    (version "7.4.47")
    (source (origin
              (method url-fetch)
              (uri "https://unpkg.com/@mdi/font@7.4.47/fonts/materialdesignicons-webfont.ttf")
              (sha256 (base32 "0a44srhk7qvypw0pzhv2bkkpc150pv6qp3kwrwigx0g9ljjsps31"))))
    (build-system gnu-build-system)
    (arguments
     '(#:tests? #f #:strip-binaries? #f #:validate-runpath? #f
       #:phases (modify-phases %standard-phases
                  (delete 'bootstrap) (delete 'configure) (delete 'check)
                  (delete 'build) (delete 'patch-usr-bin-file)
                  (delete 'patch-source-shebangs)
                  (delete 'patch-generated-file-shebangs)
                  (replace 'install
                    (lambda* (#:key outputs #:allow-other-keys)
                      (let* ((out (assoc-ref outputs "out"))
                             (font-dir (string-append out "/share/fonts/truetype")))
                        (mkdir-p font-dir)
                        (for-each (lambda (f) (copy-file f (string-append font-dir "/" (basename f))))
                                  (find-files "." "\\.ttf$")))
                      #t)))))
    (home-page "https://materialdesignicons.com")
    (synopsis "Material Design Icons font")
    (description "Extended Material Design icon font with 7000+ icons.")
    (license asl2.0)))

font-material-design-icons