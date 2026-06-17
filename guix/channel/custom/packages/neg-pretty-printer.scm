(define-module (custom packages neg-pretty-printer)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix build-system pyproject)
  #:use-module (guix licenses)
  #:use-module (gnu packages python-build)
  #:use-module (gnu packages python-xyz))

(define-public neg-pretty-printer
  (package
    (name "neg-pretty-printer")
    (version "0.1.0")
    (source (local-file "pretty-printer" #:recursive? #t))
    (build-system pyproject-build-system)
    (native-inputs (list python-setuptools python-wheel))
    (propagated-inputs (list python-colored))
    (arguments '(#:tests? #f))
    (home-page "https://github.com/neg-serg")
    (synopsis "Custom pretty-printer utilities for scripts")
    (description "Custom pretty-printer utilities providing color helpers,
file info printing, and a ppinfo CLI command.")
    (license expat)))

neg-pretty-printer
