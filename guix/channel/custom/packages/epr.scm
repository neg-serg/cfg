(define-module (custom packages epr)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system pyproject)
  #:use-module (guix licenses)
  #:use-module (gnu packages python-build))

(define-public epr
  (package
    (name "epr")
    (version "2.4.15")
    (source (origin
              (method url-fetch)
              (uri "https://github.com/wustho/epr/archive/refs/tags/v2.4.15.tar.gz")
              (sha256 (base32 "1wp0gf643w890xil3vjbdmn0fcpky2jwli320gfznssbl21sgvyl"))))
    (build-system pyproject-build-system)
    (native-inputs (list python-poetry-core))
    (arguments '(#:tests? #f))
    (home-page "https://github.com/wustho/epr")
    (synopsis "Terminal EPUB reader")
    (description "Terminal-based EPUB reader.")
    (license gpl3+)))

epr
