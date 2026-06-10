(define-module (custom packages opensoundmeter)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system trivial)
  #:use-module (guix licenses))

(define-public opensoundmeter
  (package
    (name "opensoundmeter")
    (version "1.5.2")
    (source (origin
              (method url-fetch)
              (uri "https://github.com/psmokotnin/osm/releases/download/v1.5.2/Open_Sound_Meter-v1.5.2-x86_64.AppImage")
              (sha256 (base32 "1iwj9sdx8bb9ajwnvc6g9l8iqdpdcw073ilrdk2108gdiwqihawg"))))
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
           (copy-file source (string-append bin "/opensoundmeter"))
           (chmod (string-append bin "/opensoundmeter") #o555)))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://opensoundmeter.com")
    (synopsis "Sound level meter")
    (description "Open Sound Meter for audio measurement and analysis.")
    (license gpl3+)))

opensoundmeter
