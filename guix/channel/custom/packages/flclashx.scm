(define-module (custom packages flclashx)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system trivial)
  #:use-module (guix licenses))

(define-public flclashx
  (package
    (name "flclashx")
    (version "0.3.2")
    (source (origin
              (method url-fetch)
              (uri "https://github.com/pluralplay/FlClashX/releases/download/v0.3.2/FlClashX-linux-amd64.AppImage")
              (sha256 (base32 "13060f9rzlhnw97rzkh1haz3csx14dlhxr6dnwqlmccallrzbcj5"))))
    (build-system trivial-build-system)
    (arguments
     '(#:modules ((guix build utils))
       #:builder
       (begin
         (use-modules (guix build utils))
         (let* ((source (assoc-ref %build-inputs "source"))
                (out    (assoc-ref %outputs "out"))
                (bin    (string-append out "/bin")))
           (mkdir-p bin)
           (copy-file source (string-append bin "/flclashx"))
           (chmod (string-append bin "/flclashx") #o555)))))
    (home-page "https://github.com/pluralplay/FlClashX")
    (synopsis "Proxy client GUI")
    (description "FlClashX proxy client.")
    (license gpl3+)))

flclashx
