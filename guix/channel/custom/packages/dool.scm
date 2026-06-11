(define-module (custom packages dool)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system pyproject)
  #:use-module (guix licenses))

(define-public dool
  (package
    (name "dool")
    (version "1.3.8")
    (source (origin
              (method url-fetch)
              (uri (pypi-uri "dool" version))
              (sha256
               (base32 "0000000000000000000000000000000000000000000000000000"))))
    (build-system pyproject-build-system)
    (arguments '(#:tests? #f))
    (home-page "https://github.com/scottchiefbaker/dool")
    (synopsis "Command-line system monitoring tool")
    (description "Dool is a command line tool to monitor many aspects of your
Linux system: CPU, memory, network, load average, etc.  It also includes a
robust plug-in architecture.")
    (license gpl3+)))

dool
