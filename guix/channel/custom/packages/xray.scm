(define-module (custom packages xray)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses)
  #:use-module (gnu packages compression))

(define-public xray
  (package
    (name "xray")
    (version "26.5.9")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "https://github.com/XTLS/Xray-core/"
                    "releases/download/v" version
                    "/Xray-linux-64.zip"))
              (sha256
               (base32
                "1iyisc8vm9p6cfgfq8aqq7amzxdvlpx41lycdcwasn81gimi0v7m"))))
    (build-system gnu-build-system)
    (native-inputs (list unzip))
    (arguments
     '(#:tests? #f
       #:phases (modify-phases %standard-phases
         (delete 'bootstrap)
         (delete 'configure)
         (delete 'check)
         (delete 'build)
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (let* ((out (assoc-ref outputs "out"))
                    (bin (string-append out "/bin")))
               (mkdir-p bin)
               (install-file "xray" bin)
               #t))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/XTLS/Xray-core")
    (synopsis "Xray proxy core (pre-built)")
    (description "Xray is a platform for building proxies to bypass
network restrictions.  It supports VLESS, VMess, Trojan, Shadowsocks,
SOCKS5, HTTP, and other protocols.")
    (license mpl2.0)))

xray
