(define-module (custom packages lutris)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages python)
  #:use-module (gnu packages gtk)
  #:use-module (gnu packages glib)
  #:use-module (gnu packages gnome))

(define-public lutris
  (package
    (name "lutris")
    (version "0.5.22")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://lutris.net/releases/lutris_"
                                  version ".tar.xz"))
              (sha256 (base32 "0000000000000000000000000000000000000000000000000000"))))
    (build-system gnu-build-system)
    (inputs (list python python-pygobject gtk+ glib))
    (arguments
     '(#:tests? #f
       #:phases (modify-phases %standard-phases
                  (delete 'bootstrap)
                  (delete 'configure)
                  (delete 'check)
                  (delete 'build)
                  (delete 'patch-usr-bin-file)
                  (replace 'install
                    (lambda* (#:key outputs inputs #:allow-other-keys)
                      (let* ((out (assoc-ref outputs "out"))
                             (share (string-append out "/share/lutris"))
                             (bin (string-append out "/bin")))
                        (mkdir-p share)
                        (mkdir-p bin)
                        (copy-recursively "." share)
                        ;; Create wrapper
                        (call-with-output-file (string-append bin "/lutris")
                          (lambda (port)
                            (format port "#!~a/bin/sh~%" (assoc-ref inputs "bash"))
                            (format port "export PYTHONPATH=~a/lib/python3.11/site-packages:$PYTHONPATH~%"
                                    (assoc-ref inputs "python"))
                            (format port "cd ~a~%" share)
                            (format port "exec ~a/bin/python3 ~a/bin/lutris \"$@\"~%"
                                    (assoc-ref inputs "python") share)))
                        (chmod (string-append bin "/lutris") #o555)))))))
    (home-page "https://lutris.net")
    (synopsis "Game launcher")
    (description "Lutris is a video game preservation platform that aims to keep
your video game collection up and running for years to come.")
    (license license:gpl3+)))

lutris
