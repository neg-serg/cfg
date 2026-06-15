(define-module (custom packages himalaya)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages base)
  #:use-module (gnu packages compression))

(define-public himalaya
  (package
    (name "himalaya")
    (version "1.2.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "https://github.com/pimalaya/himalaya/releases/download/v"
                    version "/himalaya.x86_64-linux.tgz"))
              (sha256
               (base32 "1r6l6sdjvcj7frr5ja2xjyi98c8i2qi1myhsn0sfyr76wf166kp0"))))
    (build-system gnu-build-system)
    (native-inputs (list tar gzip))
    (arguments
     '(#:tests? #f #:strip-binaries? #f #:validate-runpath? #f
       #:phases (modify-phases %standard-phases
                  (delete 'bootstrap)
                  (delete 'configure)
                  (delete 'check)
                  (delete 'build)
                  (delete 'patch-usr-bin-file)
                  (delete 'patch-source-shebangs)
                  (delete 'patch-generated-file-shebangs)
                  (replace 'unpack
                    (lambda* (#:key source #:allow-other-keys)
                      (invoke "tar" "xf" source)
                      #t))
                  (replace 'install
                    (lambda* (#:key outputs #:allow-other-keys)
                      (let* ((out (assoc-ref outputs "out"))
                             (bin (string-append out "/bin"))
                             (share (string-append out "/share")))
                        (mkdir-p bin)
                        (copy-file "himalaya" (string-append bin "/himalaya"))
                        (chmod (string-append bin "/himalaya") #o555)
                        (when (file-exists? "share")
                          (copy-recursively "share" share))
                        #t))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://pimalaya.org/himalaya/")
    (synopsis "Command-line email client")
    (description "Himalaya is a CLI email client written in Rust that
supports multiple backends including IMAP, Maildir, and Notmuch.")
    (license license:expat)))

himalaya
