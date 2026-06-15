(define-module (custom packages wsdd)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses)
  #:use-module (gnu packages python))

(define-public wsdd
  (package
    (name "wsdd")
    (version "0.8")
    (source (origin
              (method git-fetch)
              (uri (git-reference
                    (url "https://github.com/christgau/wsdd")
                    (commit (string-append "v" version))))
              (file-name (git-file-name name version))
              (sha256 (base32 "1qj5z0j6hhvvydwrx9mxayw6cvq4j01jzvn2rd6jpq3i1aaxgksg"))))
    (build-system gnu-build-system)
    (inputs (list python))
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
                        (copy-file "src/wsdd.py"
                                   (string-append bin "/wsdd"))
                        (chmod (string-append bin "/wsdd") #o755)
                        (wrap-program (string-append bin "/wsdd")
                          `("PATH" ":" prefix
                            (,(string-append (assoc-ref %build-inputs "python")
                                             "/bin"))))))))))
    (home-page "https://github.com/christgau/wsdd")
    (synopsis "Web Services Dynamic Discovery (WS-Discovery) daemon")
    (description "WSDD implements a WS-Discovery host daemon for Samba
shares.  It makes Samba hosts visible in Windows network neighborhood.")
    (license expat)))

wsdd
