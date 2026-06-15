(define-module (custom packages grafana)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses))

(define-public grafana
  (package
    (name "grafana")
    (version "13.0.2")
    (source
      (origin
        (method url-fetch)
        (uri (string-append
               "https://dl.grafana.com/oss/release/grafana-"
               version ".linux-amd64.tar.gz"))
        (sha256
          (base32
            "0bfzbqb599aafmg5wa47rm69c4hc90w0pwvv7fry54ldnjqdh837"))))
    (build-system gnu-build-system)
    (arguments
     '(#:tests? #f
       #:strip-binaries? #f
       #:validate-runpath? #f
       #:phases (modify-phases %standard-phases
         (delete 'bootstrap)
         (delete 'configure)
         (delete 'check)
         (delete 'build)
         (delete 'patch-usr-bin-file)
         (delete 'patch-source-shebangs)
         (delete 'patch-generated-file-shebangs)
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (let* ((out    (assoc-ref outputs "out"))
                    (shared (string-append out "/share/grafana"))
                    (bin    (string-append out "/bin")))
               (mkdir-p bin)
               (copy-recursively "." shared)
               (symlink (string-append shared "/bin/grafana")
                        (string-append bin "/grafana"))
               #t))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://grafana.com")
    (synopsis "Observability and monitoring dashboard")
    (description "Grafana is a multi-platform open source analytics and
interactive visualization web application.  It provides charts, graphs, and
alerts for the web when connected to supported data sources.")
    (license agpl3+)))

grafana
