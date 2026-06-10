(define-module (custom packages zapret2)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses))

(define-public zapret2
  (package
    (name "zapret2")
    (version "0.9.5.2")
    (source
      (origin
        (method url-fetch)
        (uri (string-append
               "https://github.com/bol-van/zapret2/releases/download/v"
               "0.9.5.2" "/zapret2-v0.9.5.2.tar.gz"))
        (sha256
          (base32
            "1j0d125c6rnn3mzqyahmbr2za1bhdnxqapr1r8vik6kwc7y151jg"))))
    (build-system gnu-build-system)
    (arguments
     '(#:tests? #f
       #:validate-runpath? #f
       #:phases (modify-phases %standard-phases
         (delete 'bootstrap)
         (delete 'configure)
         (delete 'check)
         (delete 'build)
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (let* ((out (assoc-ref outputs "out"))
                    (opt (string-append out "/opt/zapret2")))
               (mkdir-p opt)
               (copy-recursively "." opt)
               #t))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/bol-van/zapret2")
    (synopsis "DPI bypass tool")
    (description "Tool for bypassing Deep Packet Inspection blocking.
Install by running /opt/zapret2/install_easy.sh")
    (license gpl3+)))

zapret2
