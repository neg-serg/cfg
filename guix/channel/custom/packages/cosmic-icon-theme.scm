(define-module (custom packages cosmic-icon-theme)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses))

(define-public cosmic-icon-theme
  (package
    (name "cosmic-icon-theme")
    (version "1.0.0")
    (source (origin
              (method git-fetch)
              (uri (git-reference
                     (url "https://github.com/pop-os/cosmic-icons")
                     (commit "2c697e8e97cfd619107a872b28c31317281184ff")))
               (file-name (git-file-name name version))
               (sha256 (base32 "0000000000000000000000000000000000000000000000000000"))))
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
                      (let ((out (assoc-ref outputs "out"))
                            (icon-dir "share/icons"))
                        (mkdir-p (string-append out "/" icon-dir))
                        (for-each (lambda (d)
                                    (copy-recursively d
                                      (string-append out "/" icon-dir "/" d)))
                                  (scandir "."
                                    (lambda (f)
                                      (and (not (member f '("." "..")))
                                           (not (string-prefix? "." f))
                                           (eq? 'directory (stat:type (stat f)))))))
                        #t))))))
    (home-page "https://github.com/pop-os/cosmic-icons")
    (synopsis "COSMIC icon theme")
    (description "Icon theme for the COSMIC desktop environment.")
    (license cc-by-sa4.0)))

cosmic-icon-theme
