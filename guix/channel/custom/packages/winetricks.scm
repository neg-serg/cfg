(define-module (custom packages winetricks)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses)
  #:use-module (gnu packages base)
  #:use-module (gnu packages bash))

(define-public winetricks
  (package
    (name "winetricks")
    (version "20250102")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "https://github.com/Winetricks/winetricks/archive/"
                    version ".tar.gz"))
              (sha256
               (base32
                "0bp4xd794z1qdn8h3h1llpszwrdryxpxfhq7wx72f29kds03klr4"))))
    (build-system gnu-build-system)
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
               (install-file "src/winetricks" bin)
               #t))))))
    (home-page "https://github.com/Winetricks/winetricks")
    (synopsis "Work around common problems in Wine")
    (description "Winetricks lets you install missing DLLs or tweak
various Wine settings individually.")
    (license lgpl2.1+)))

winetricks
