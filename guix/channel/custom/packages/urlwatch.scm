(define-module (custom packages urlwatch)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system python)
  #:use-module (guix licenses)
  #:use-module (gnu packages python-build)
  #:use-module (gnu packages python-crypto)
  #:use-module (gnu packages python-web)
  #:use-module (gnu packages python-xyz)
  #:use-module (gnu packages xml)
  #:use-module (custom packages python-minidb))

(define-public urlwatch
  (package
    (name "urlwatch")
    (version "2.29")
    (source (origin
              (method url-fetch)
              (uri "https://files.pythonhosted.org/packages/76/a3/e3bc54a669fa3ec440ea9d8db64590e761343b02b6ae9fcfcdc05c28d9ea/urlwatch-2.29.tar.gz")
              (sha256 (base32 "166scrrpa390xmfkw982ymsbba6qhpw8pq691r8sy59v2a5wl5zk"))))
    (build-system python-build-system)
    (native-inputs (list python-setuptools))
    (propagated-inputs (list python-minidb
                             python-pyyaml
                             python-requests
                             python-keyring
                             python-platformdirs
                             python-lxml
                             python-cssselect))
    (arguments '(#:tests? #f))
    (home-page "https://thp.io/2008/urlwatch/")
    (synopsis "Monitors web pages for changes")
    (description "urlwatch is intended to help you notice changes in web pages and
other online resources.  You define a list of URLs to monitor and urlwatch
sends you a diff of what has changed when it detects differences.")
    (license bsd-3)))

urlwatch
