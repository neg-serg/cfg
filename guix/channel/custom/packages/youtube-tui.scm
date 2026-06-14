(define-module (custom packages youtube-tui)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system trivial)
  #:use-module ((guix licenses) #:prefix license:))

(define-public youtube-tui
  (package
    (name "youtube-tui")
    (version "0.9.4")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "https://github.com/Siriusmart/youtube-tui/releases/download/v"
                    version "/youtube-tui-full_arch-x86_64"))
              (file-name (string-append name "-" version))
              (sha256 (base32 "1j9b3ws26gk37hs89y0phbxqlfvvlyg1kf89r26mg1g5pmn8x2f8"))))
    (build-system trivial-build-system)
    (supported-systems '("x86_64-linux"))
    (arguments
     `(#:modules ((guix build utils))
       #:builder
       (begin
         (use-modules (guix build utils))
         (let* ((source (assoc-ref %build-inputs "source"))
                (out    (assoc-ref %outputs "out"))
                (bin    (string-append out "/bin"))
                (target (string-append bin "/youtube-tui")))
           (mkdir-p bin)
           (copy-file source target)
           (chmod target #o555)))))
    (home-page "https://tui.siri.ws/youtube")
    (synopsis "YouTube TUI")
    (description "An aesthetically pleasing YouTube TUI written in Rust.")
    (license license:gpl3+)))

youtube-tui
