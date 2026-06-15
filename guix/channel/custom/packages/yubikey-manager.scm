(define-module (custom packages yubikey-manager)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system pyproject)
  #:use-module (guix licenses)
  #:use-module (gnu packages python-build)
  #:use-module (gnu packages python-crypto)
  #:use-module (gnu packages python-xyz)
  #:use-module (gnu packages security-token)
  #:use-module (custom packages python-pskc))

(define-public yubikey-manager
  (package
    (name "yubikey-manager")
    (version "5.9.1")
    (source
      (origin
        (method url-fetch)
        (uri "https://files.pythonhosted.org/packages/82/f8/909641e6a9fe3bf315df9032a2875eff5981b95c90df55f269506fadb6c9/yubikey_manager-5.9.1.tar.gz")
        (sha256
          (base32
            "1sxhmgcfxlvdram1d4asr08via75607kmrsxgv03padnpfja5gc3"))))
    (build-system pyproject-build-system)
    (native-inputs (list python-poetry-core))
    (propagated-inputs (list python-click
                             python-cryptography
                             python-fido2
                             python-keyring
                             python-pyscard
                             python-pskc))
    (arguments '(#:tests? #f))
    (home-page "https://developers.yubico.com/yubikey-manager/")
    (synopsis "CLI tool for managing YubiKey configuration")
    (description "YubiKey Manager (ykman) is a command line tool for configuring
YubiKeys.  It provides the ability to manage applications, credentials, and
device settings on YubiKey hardware security keys.")
    (license asl2.0)))

yubikey-manager
