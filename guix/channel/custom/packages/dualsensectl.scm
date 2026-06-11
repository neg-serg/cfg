(define-module (custom packages dualsensectl)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module (guix build-system meson)
  #:use-module (guix licenses)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages pkg-config))

(define-public dualsensectl
  (package
    (name "dualsensectl")
    (version "0.7")
    (source (origin
              (method git-fetch)
              (uri (git-reference
                    (url "https://github.com/nowrep/dualsensectl")
                    (commit (string-append "v" version))))
              (file-name (git-file-name name version))
               (sha256 (base32 "0wkbrsc70qv8gkzfsc527mjw637yw4qryj8a5nqkhmwjjr2k05d6"))))
    (build-system meson-build-system)
    (native-inputs (list pkg-config))
    (inputs (list eudev hidapi))
    (arguments '(#:tests? #f))
    (home-page "https://github.com/nowrep/dualsensectl")
    (synopsis "Linux tool for controlling PS5 DualSense controllers")
    (description "DualSense Control is a Linux tool for controlling Sony
PlayStation 5 DualSense controllers from the command line.")
    (license gpl2)))

dualsensectl
