(define-module (custom packages pop-icon-theme)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module (guix build-system gnu)
  #:use-module (guix build utils)
  #:use-module (guix licenses))

(define-public pop-icon-theme
  (package
    (name "pop-icon-theme")
    (version "2024.12.01")
    (source (origin
              (method git-fetch)
              (uri (git-reference
                    (url "https://github.com/pop-os/icon-theme")
                    (commit "1a575a8e99b4ae629b9b16543a3a04d148632ba9")))
              (file-name (git-file-name name version))
              (sha256 (base32 "0fqh6w2dnzn8ncaas2x6w3znsfa2r4g4gnzj719jdm924gxazm86"))))
    (build-system gnu-build-system)
    (arguments
     '(#:tests? #f #:strip-binaries? #f #:validate-runpath? #f
       #:modules ((guix build gnu-build-system)
                  (guix build utils)
                  (ice-9 ftw))
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
    (home-page "https://github.com/pop-os/icon-theme")
    (synopsis "Pop!_OS icon theme")
    (description "Icon theme from Pop!_OS by System76.")
    (license cc-by-sa4.0)))

pop-icon-theme
