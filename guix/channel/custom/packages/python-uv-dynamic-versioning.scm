(define-module (custom packages python-uv-dynamic-versioning)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system pyproject)
  #:use-module (guix licenses)
  #:use-module (gnu packages python-build)
  #:use-module (gnu packages python-xyz)
  #:use-module (gnu packages version-control))

(define-public python-uv-dynamic-versioning
  (package
    (name "python-uv-dynamic-versioning")
    (version "0.14.0")
    (source (origin
              (method url-fetch)
              (uri "https://files.pythonhosted.org/packages/15/ef/63270118de5af8f45ba417946290b63f86b0b2a7d07d739d5dc619462711/uv_dynamic_versioning-0.14.0.tar.gz")
              (sha256 (base32 "0nyvr1x24qf2hynbixcgp5bi51v4p39pm5jm3p04bkksx03vqksp"))))
    (build-system pyproject-build-system)
    (native-inputs (list python-hatchling))
    (inputs (list python-dunamai python-hatchling python-jinja2
                  python-pydantic python-tomlkit git))
    (arguments '(#:tests? #f))
    (home-page "https://github.com/ninoseki/uv-dynamic-versioning")
    (synopsis "Hatch plugin for dynamic versioning from VCS tags")
    (description "Hatch plugin for dynamic versioning from VCS tags.")
    (license expat)))

python-uv-dynamic-versioning
