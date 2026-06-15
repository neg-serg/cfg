(define-module (custom packages geoip)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses))

(define-public geoip
  (package
    (name "geoip")
    (version "1.6.12")
    (source
      (origin
        (method url-fetch)
        (uri "https://github.com/maxmind/geoip-api-c/releases/download/v1.6.12/GeoIP-1.6.12.tar.gz")
        (sha256
          (base32
            "103gcf4q6f8hd57mhiwm81pmsgb3hvblr35savyvgr650f079yqx"))))
    (build-system gnu-build-system)
    (arguments '(#:tests? #f))
    (home-page "https://github.com/maxmind/geoip-api-c")
    (synopsis "GeoIP legacy C library and CLI tools")
    (description "Legacy MaxMind GeoIP C API providing geoiplookup and
geoiplookup6 command-line tools for IP geolocation lookups.
Requires GeoIP database files (e.g. from geoip-database package).")
    (license lgpl2.1+)))

geoip
