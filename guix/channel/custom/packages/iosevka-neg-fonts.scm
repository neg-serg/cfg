(define-module (custom packages iosevka-neg-fonts)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses))

;; Custom Iosevka Nerd Fonts built from iosevka-neg.toml config
;; Blob: tar czf iosevka-neg-fonts.tar.gz *.ttf from /usr/share/fonts/TTF/Iosevka-*
(define-public font-iosevka-neg
  (package
    (name "font-iosevka-neg")
    (version "34.1.0")
    (source (local-file "iosevka-neg-fonts.tar.gz"))
    (build-system gnu-build-system)
    (arguments
     '(#:tests? #f #:strip-binaries? #f #:validate-runpath? #f
       #:phases (modify-phases %standard-phases
         (delete 'bootstrap) (delete 'configure) (delete 'check)
         (delete 'build) (delete 'patch-usr-bin-file)
         (delete 'patch-source-shebangs) (delete 'patch-generated-file-shebangs)
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (let* ((out (assoc-ref outputs "out"))
                    (fontdir (string-append out "/share/fonts/truetype")))
               (mkdir-p fontdir)
               (for-each (lambda (f)
                           (install-file f fontdir))
                         (find-files "." "\\.ttf$"))
               #t))))))
    (home-page "https://github.com/be5invis/Iosevka")
    (synopsis "Custom Iosevka Nerd Fonts (neg variant)")
    (description "Custom-built Iosevka fonts with Nerd Font patching,
styled according to the neg-serg iosevka-neg.toml configuration.")
    (license silofl1.1)))
