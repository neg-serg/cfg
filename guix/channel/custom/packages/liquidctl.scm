(define-module (custom packages liquidctl)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system pyproject)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages libusb)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages python-build)
  #:use-module (gnu packages python-crypto)
  #:use-module (gnu packages python-xyz)
  #:use-module (gnu packages serialization))

(define-public liquidctl
  (package
    (name "liquidctl")
    (version "1.16.0")
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "https://files.pythonhosted.org/packages/7f/9c/11f37716eeeccc72a781c80e76021a33cafa35578627263199ea62b2eb2d/liquidctl-"
             version ".tar.gz"))
       (sha256
        (base32 "13sgc768bahdbgvgvvf2v1lc3708njcjb9rb9163103rq7wsjcdn"))))
    (build-system pyproject-build-system)
    (native-inputs (list python-setuptools python-wheel))
    (propagated-inputs (list python-colorlog
                             python-crcmod
                             python-docopt
                             python-hidapi
                             python-pyusb
                             python-ruamel.yaml
                             python-smbus))
    (arguments '(#:tests? #f
                 #:phases (modify-phases %standard-phases
                            (delete 'sanity-check))))
    (home-page "https://github.com/liquidctl/liquidctl")
    (synopsis "Cross-platform tool for liquid cooler and other device control")
    (description "liquidctl is a cross-platform CLI tool and driver for monitoring
and controlling liquid coolers, fan controllers, LED controllers, DRAM modules,
and power supplies from various manufacturers including NZXT, Corsair, EVGA,
ASUS, Gigabyte, and Aquacomputer.")
    (license license:gpl3+)))

liquidctl
