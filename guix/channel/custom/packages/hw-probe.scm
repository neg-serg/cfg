(define-module (custom packages hw-probe)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses)
  #:use-module (gnu packages perl)
  #:use-module (gnu packages curl)
  #:use-module (gnu packages pciutils)
  #:use-module (gnu packages linux))

(define-public hw-probe
  (package
    (name "hw-probe")
    (version "1.6.6")
    (source (origin
              (method git-fetch)
              (uri (git-reference
                    (url "https://github.com/linuxhw/hw-probe")
                    (commit version)))
              (file-name (git-file-name name version))
              (sha256 (base32 "0000000000000000000000000000000000000000000000000000"))))
    (build-system gnu-build-system)
    (inputs (list perl
                  curl
                  pciutils
                  usbutils
                  util-linux
                  hwinfo
                  smartmontools
                  dmidecode))
    (arguments
     '(#:tests? #f
       #:phases (modify-phases %standard-phases
                  (delete 'configure)
                  (delete 'check)
                  (replace 'build
                    (lambda _
                      (invoke "make" "prefix=/"))))))
    (home-page "https://github.com/linuxhw/hw-probe")
    (synopsis "Hardware probe tool for Linux")
    (description "HW Probe is a tool to probe for hardware, check
operability and find drivers.  It collects system hardware information
and can upload to the linux-hardware.org database.")
    (license lgpl2.1+)))

hw-probe
