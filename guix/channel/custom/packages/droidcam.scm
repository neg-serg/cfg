(define-module (custom packages droidcam)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module ((guix licenses) #:select (gpl2+))
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages gtk)
  #:use-module (gnu packages xorg)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages glib)
  #:use-module (gnu packages tls)
  #:use-module (gnu packages curl)
  #:use-module (gnu packages libusb)
  #:use-module (gnu packages xiph)
  #:use-module (gnu packages video))

(define-public droidcam
  (package
    (name "droidcam")
    (version "2.1.5")
    (source (origin
              (method url-fetch)
              (uri "https://github.com/dev47apps/droidcam-linux-client/archive/refs/tags/v2.1.5.tar.gz")
              (sha256 (base32 "1y11f0c1c4kc699vzbbdfqswd2dg2inm7p1azczlw3k6gbn9dv00"))))
    (build-system gnu-build-system)
    (native-inputs (list pkg-config))
    (inputs (list gtk+ libx11 libusbmuxd openssl curl alsa-lib speex ffmpeg))
    (arguments
     '(#:tests? #f
       #:phases (modify-phases %standard-phases
         (delete 'configure)
         (add-after 'unpack 'fix-deps
           (lambda _
             ;; Remove appindicator dependency (not in Guix)
             (substitute* "src/droidcam.c"
               (("#include <libappindicator/app-indicator.h>") "")
               (("APPINDICATOR_SIMPLE_INDICATOR") ""))
             #t))
         (replace 'build
           (lambda* (#:key #:allow-other-keys)
             (invoke "make" "droidcam" "CC=gcc" "APPINDICATOR=")
             #t))
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (let* ((out (assoc-ref outputs "out"))
                    (bin (string-append out "/bin")))
               (mkdir-p bin)
               (install-file "droidcam" bin))
             #t)))))
    (home-page "https://github.com/dev47apps/droidcam-linux-client")
    (synopsis "Use Android phone as webcam")
    (description "Use your Android phone as a wireless webcam.")
    (license gpl2+)))

droidcam
