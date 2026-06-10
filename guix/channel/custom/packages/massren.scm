(define-module (custom packages massren)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system go)
  #:use-module (guix licenses))

(define-public massren
  (package
    (name "massren")
    (version "1.5.7")
    (source (origin
              (method url-fetch)
              (uri "https://github.com/laurent22/massren/archive/refs/tags/v1.5.7.tar.gz")
              (sha256 (base32 "133s0cnpjp071sb3jbz2pvcssnx3nn2cd3168x926r1kpm4x2zby"))))
    (build-system go-build-system)
    (arguments
     '(#:tests? #f
       #:import-path "github.com/laurent22/massren"))
    (home-page "https://github.com/laurent22/massren")
    (synopsis "Bulk file rename tool")
    (description "Easily rename multiple files using your text editor.")
    (license expat)))

massren
