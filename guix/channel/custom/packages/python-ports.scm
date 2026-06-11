(define-module (custom packages python-ports)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system pyproject)
  #:use-module ((guix build-system python) #:hide (pypi-uri))
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages python)
  #:use-module (gnu packages python-build)
  #:use-module (gnu packages python-xyz)
  #:use-module (gnu packages vim))

(define-public python-ascii-magic
  (package
    (name "python-ascii-magic")
    (version "2.7.5")
    (source
     (origin
       (method url-fetch)
       (uri (pypi-uri "ascii_magic" version))
       (sha256
        (base32 "07n3finj98x11l7ncnj365n78n40pqd46dwj8b3pglk0xbj1cxym"))))
    (build-system pyproject-build-system)
    (propagated-inputs (list python-pillow))
    (arguments '(#:tests? #f))
    (native-inputs (list python-setuptools))
    (home-page "https://github.com/LeandroBarone/python-ascii_magic")
    (synopsis "Converts pictures into ASCII art")
    (description "Converts pictures into ASCII art.")
    (license #f)))

(define-public python-neovim-remote
  (package
    (name "python-neovim-remote")
    (version "2.5.1")
    (source
     (origin
       (method url-fetch)
       (uri (pypi-uri "neovim-remote" version))
       (sha256
        (base32 "00kxlb3f1k7iaxzpsr07scavmnyg8c1jmicmr13mfk2lcdac6g2b"))))
    (build-system pyproject-build-system)
    (propagated-inputs (list python-psutil python-pynvim python-setuptools))
    (native-inputs (list python-setuptools))
    (arguments '(#:tests? #f))
    (home-page "https://github.com/mhinz/neovim-remote")
    (synopsis "Control nvim processes using \"nvr\" commandline tool")
    (description "Control nvim processes using \"nvr\" commandline tool.")
    (license license:expat)))

(define-public python-rapidgzip
  (package
    (name "python-rapidgzip")
    (version "0.16.0")
    (source
     (origin
       (method url-fetch)
       (uri (pypi-uri "rapidgzip" version))
       (sha256
        (base32 "0kn1l7yxkh3l3fvarx4g38m78rsysdd3xs41md4l5phjphlly4lb"))))
    (build-system pyproject-build-system)
    (native-inputs (list python-cython python-setuptools))
    (arguments '(#:tests? #f))
    (home-page "https://github.com/mxmlnkn/rapidgzip")
    (synopsis "Parallel random access to gzip files")
    (description "Parallel random access to gzip files.")
    (license license:expat)))

(define-public python-scdl
  (package
    (name "python-scdl")
    (version "3.0.4")
    (source
     (origin
       (method url-fetch)
       (uri (pypi-uri "scdl" version))
       (sha256
        (base32 "1m89dfvzwhhyv1gkqc7mlvxbvdmahsv9kqwnzqb4sn4khar2zdxg"))))
    (build-system pyproject-build-system)
    (propagated-inputs (list python-curl-cffi python-docopt-ng python-mutagen
                             python-soundcloud-v2             python-yt-dlp))
    (arguments '(#:tests? #f))
    (home-page #f)
    (synopsis "Download Music from Souncloud")
    (description "Download Music from Souncloud.")
    (license #f)))

(define-public python-cmake-language-server
  (package
    (name "python-cmake-language-server")
    (version "0.1.11")
    (source (origin
              (method url-fetch)
              (uri (pypi-uri "cmake_language_server" version))
              (sha256 (base32 "0nv9rnry4nkjknrmhy34mjndskq4c9kqz999f9x4asf5gqv4hpq0"))))
    (build-system pyproject-build-system)
    (propagated-inputs (list python-pygls))
    (native-inputs (list python-pdm-backend))
    (arguments '(#:tests? #f))
    (home-page #f)
    (synopsis "CMake LSP Implementation")
    (description "CMake LSP Implementation.")
    (license #f)))

(define-public python-texicode
  (package
    (name "python-texicode")
    (version "0.1.1")
    (source (origin
              (method url-fetch)
              (uri (pypi-uri "texicode" version))
              (sha256 (base32 "02dvxz3s59ghz014j4n3j83clm6wwlwp0n2xjvw1bvvjv9ik48zr"))))
    (build-system pyproject-build-system)
    (arguments '(#:tests? #f))
    (home-page #f)
    (synopsis "TeX to Unicode converter")
    (description "TeX to Unicode converter.")
    (license #f)))

(define-public python-sqlit
  (package
    (name "python-sqlit")
    (version "0.1.1")
    (source (origin
              (method url-fetch)
              (uri (pypi-uri "sqlit" version))
              (sha256 (base32 "0x9vm1880fx62xhfydcww51p2q3d1rp75fkgbfq5bzxbw7mvi14y"))))
    (build-system pyproject-build-system)
    (arguments '(#:tests? #f))
    (home-page #f)
    (synopsis "SQLite query tool")
    (description "SQLite query tool.")
    (license #f)))

(define-public python-vdf
  (package
    (name "python-vdf")
    (version "3.4")
    (source
     (origin
       (method url-fetch)
       (uri (pypi-uri "vdf" version))
       (sha256
        (base32 "1bz2gn04pl6rj2mawlzlirz1ygg4rdypq0pxbyg018873vs1jm7x"))))
    (build-system pyproject-build-system)
    (arguments '(#:tests? #f))
    (native-inputs (list python-setuptools))
    (home-page "https://github.com/ValvePython/vdf")
    (synopsis "Library for working with Valve's VDF text format")
    (description "Library for parsing and serializing Valve's KeyValue text format.")
    (license license:expat)))
