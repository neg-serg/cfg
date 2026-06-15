(define-module (custom packages httpie)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system pyproject)
  #:use-module (guix build-system python)
  #:use-module (gnu packages python-web)
  #:use-module (gnu packages python-build)
  #:use-module (gnu packages python-xyz)
  #:use-module (gnu packages xml)
  #:use-module ((guix licenses) #:prefix license:))

(define-public httpie
  (package
    (name "httpie")
    (version "3.2.4")
    (source (origin
              (method url-fetch)
              (uri (pypi-uri "httpie" version))
              (sha256
               (base32 "0aks5qg707sjqbrhbdclrmmi8aynz0p5gm0r3c6zs56wqcvd8aih"))))
    (build-system python-build-system)
    (arguments
     '(#:tests? #f
       #:phases (modify-phases %standard-phases
                  (delete 'sanity-check))))
    (native-inputs
     (list python-setuptools))
    (inputs
     (list python-requests
           python-pygments
           python-rich
           python-multidict
           python-defusedxml
           python-requests-toolbelt))
    (home-page "https://httpie.io")
    (synopsis "Human-friendly CLI HTTP client")
    (description "HTTPie is a command-line HTTP client. Its goal is to make CLI interaction with web services as human-friendly as possible. HTTPie is designed for testing, debugging, and generally interacting with APIs and HTTP servers.")
    (license license:bsd-3)))

httpie
