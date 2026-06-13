(define-module (custom packages ambxst)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses)
  #:use-module (gnu packages elf)
  #:use-module (gnu packages base)
  #:use-module (custom packages quickshell))

(define-public ambxst
  (package
    (name "ambxst")
    (version "1.1.5")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "https://github.com/Axenide/Ambxst/archive/refs/tags/"
                    version ".tar.gz"))
              (sha256
               (base32 "1yhqabd5wkz883yljpd7vqg6clkx8rb9jr5c2lhvjlc7qnv9shhv"))))
    (build-system gnu-build-system)
    (arguments
     `(#:tests? #f
       #:phases (modify-phases %standard-phases
         (delete 'bootstrap) (delete 'configure) (delete 'check) (delete 'build)
         (replace 'install
           (lambda* (#:key outputs inputs #:allow-other-keys)
             (let* ((out   (assoc-ref outputs "out"))
                    (bdir  (string-append out "/bin"))
                    (sdir  (string-append out "/share/ambxst"))
                    (qs    (string-append (assoc-ref inputs "quickshell") "/bin/qs")))
               (mkdir-p bdir)
               (mkdir-p sdir)
               ;; Copy all Ambxst QML/JS/config files
               (copy-recursively "." sdir)
               ;; Create launcher script
               (with-output-to-file (string-append bdir "/ambxst")
                 (lambda ()
                   (format #t "#!/bin/sh
export AMBXST_QS=~a
export QML2_IMPORT_PATH=\"$HOME/.local/lib/qml:$QML2_IMPORT_PATH\"
export QML_IMPORT_PATH=\"$QML2_IMPORT_PATH\"
exec ~a -p ~a/shell.qml \"$@\"
" qs qs sdir)))
               (chmod (string-append bdir "/ambxst") #o555))
             #t)))))
    (inputs (list quickshell))
    (supported-systems '("x86_64-linux"))
    (home-page "https://axeni.de/ambxst/")
    (synopsis "Axtremely customizable Wayland shell")
    (description "Ambxst is a highly customizable Wayland shell built with Quickshell.
It provides a unified panel (bar, dock, notch), dashboard, lockscreen,
desktop widgets, and notification system.")
    (license gpl3+)))
