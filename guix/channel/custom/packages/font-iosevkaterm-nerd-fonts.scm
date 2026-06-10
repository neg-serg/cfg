(define-module (custom packages font-iosevkaterm-nerd-fonts)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses))

(define-public font-iosevkaterm-nerd-fonts
  (package
    (name "font-iosevkaterm-nerd-fonts")
    (version "3.4.0")
    (source (origin
              (method url-fetch)
              (uri "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/IosevkaTerm.tar.xz")
              (sha256 (base32 "10dpyn6c13yqw2cslsq1xqaykry9yg91k8qmg8zl3qr55mbxmnfa"))))
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
    (home-page "https://www.nerdfonts.com")
    (synopsis "Iosevka Term Nerd Font")
    (description "Iosevka Term font with Nerd Font patches (icons).")
    (license (list expat silofl1.1))))

font-iosevkaterm-nerd-fonts