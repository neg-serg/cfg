(define-module (custom packages python-pskc)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system python)
  #:use-module (guix licenses)
  #:use-module (gnu packages python-build)
  #:use-module (gnu packages python-crypto)
  #:use-module (gnu packages time))

(define-public python-pskc
  (package
    (name "python-pskc")
    (version "1.4")
    (source
      (origin
        (method url-fetch)
        (uri "https://files.pythonhosted.org/packages/bb/96/877a597fc0bd9a3ed33ada8b30a93f9705805dc43a330e048a8bb1078365/python_pskc-1.4.tar.gz")
        (sha256
          (base32
            "1zpfadvdig0af71hggsksld9vgcds6s023mk53kpn1na8qa3hdja"))))
    (build-system python-build-system)
    (native-inputs (list python-setuptools))
    (propagated-inputs (list python-cryptography python-dateutil))
    (arguments '(#:tests? #f))
    (home-page "https://arthurdejong.org/python-pskc/")
    (synopsis "Python PSKC library (RFC 6030)")
    (description "Python module for handling Portable Symmetric Key Container (PSKC)
files as defined in RFC 6030.  PSKC files are used to transport and provision
symmetric keys and key meta data to different types of crypto modules.")
    (license lgpl2.1+)))

python-pskc
