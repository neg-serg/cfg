(define-module (custom packages sonic-visualiser)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system trivial)
  #:use-module (guix licenses))

(define-public sonic-visualiser
  (package
    (name "sonic-visualiser")
    (version "5.2.1")
    (source (origin
              (method url-fetch)
              (uri "https://github.com/sonic-visualiser/sonic-visualiser/releases/download/sv_v5.2.1/SonicVisualiser-5.2.1-x86_64.AppImage")
              (sha256 (base32 "172rk33rv2m078lbd0jazp1x54y10q50q19wjkjxdadp1nbpn7p3"))))
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
           (copy-file source (string-append bin "/sonic-visualiser"))
           (chmod (string-append bin "/sonic-visualiser") #o555)))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://www.sonicvisualiser.org")
    (synopsis "Audio analysis and visualisation tool")
    (description "Sonic Visualiser is a program for viewing and analysing the
contents of music audio files.  It provides high-quality interactive
visualisations of spectrograms, waveforms, and other audio analysis
data, with support for annotation layers and Vamp audio analysis
plugins.")
    (license gpl2+)))

sonic-visualiser
