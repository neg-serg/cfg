(define-module (custom packages python-minidb)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system python)
  #:use-module (guix licenses)
  #:use-module (gnu packages python-build))

(define-public python-minidb
  (package
    (name "python-minidb")
    (version "2.0.8")
    (source (origin
              (method url-fetch)
              (uri "https://files.pythonhosted.org/packages/aa/ea/5b803a05d523733735f8581cc8a51306cbea1a65ee4a5067abd98a969c4b/minidb-2.0.8.tar.gz")
              (sha256 (base32 "07365j60bxp5iyy8yyyyhbx2q8gjs1yvfm1nv2zc46fcaf3p91fr"))))
    (build-system python-build-system)
    (native-inputs (list python-setuptools))
    (arguments '(#:tests? #f))
    (home-page "https://thp.io/2010/minidb/")
    (synopsis "Pure Python SQLite-based object store")
    (description "minidb is a simple SQLite3-based store for Python objects.")
    (license isc)))

python-minidb
