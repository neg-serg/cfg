(define-module (custom packages yamllint)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system pyproject)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages python)
  #:use-module (gnu packages python-build)
  #:use-module (gnu packages python-xyz))

(define-public yamllint
  (package
    (name "yamllint")
    (version "1.38.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "https://files.pythonhosted.org/packages/source/y/yamllint/yamllint-"
                    version ".tar.gz"))
              (sha256
               (base32 "0k9n3mykh9y90j7k4h0axy8idsfm35hffqdhdcv97ays66az5r89"))))
    (build-system pyproject-build-system)
    (arguments
     '(#:tests? #f
       #:phases (modify-phases %standard-phases
                  (add-after 'unpack 'relax-pathspec
                    (lambda _
                      (substitute* "pyproject.toml"
                        (("pathspec >= 1\\.0\\.0") "pathspec >= 0.12.0"))
                      #t)))))
    (native-inputs (list python-setuptools python-wheel))
    (propagated-inputs (list python-pyyaml python-pathspec))
    (home-page "https://github.com/adrienverge/yamllint")
    (synopsis "Linter for YAML files")
    (description "yamllint checks YAML files for syntax validity,
key repetition, cosmetic problems such as lines length, trailing
spaces, indentation, and more.")
    (license license:gpl3+)))

yamllint
