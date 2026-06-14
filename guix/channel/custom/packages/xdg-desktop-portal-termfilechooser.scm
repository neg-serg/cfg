(define-module (custom packages xdg-desktop-portal-termfilechooser)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses))

(define-public xdg-desktop-portal-termfilechooser
  (package
    (name "xdg-desktop-portal-termfilechooser")
    (version "1.4.0")
    (source (origin
              (method url-fetch)
              (uri "https://github.com/hunkyburrito/xdg-desktop-portal-termfilechooser/archive/refs/tags/v1.4.0.tar.gz")
              (sha256 (base32 "0pvnjgxdqyx5zg0mxml6vgjwmysbcxh4wgsh866xdmk9x09n5wmn"))))
    (build-system gnu-build-system)
    (arguments
     '(#:tests? #f #:strip-binaries? #f #:validate-runpath? #f #:patch-shebangs? #f
       #:phases (modify-phases %standard-phases
                  (delete 'bootstrap) (delete 'configure) (delete 'check)
                  (delete 'build) (delete 'patch-usr-bin-file)
                  (delete 'patch-source-shebangs)
                  (delete 'patch-generated-file-shebangs)
                   (replace 'install
                     (lambda* (#:key outputs #:allow-other-keys)
                       (let* ((out (assoc-ref outputs "out"))
                              (bin (string-append out "/bin"))
                              (libexec (string-append out "/libexec")))
                         (mkdir-p bin)
                         (for-each
                           (lambda (f)
                             (let ((target (string-append bin "/" (basename f))))
                               (copy-file f target)
                               (chmod target #o555)))
                           (find-files "contrib" "\\.sh$")))
                       #t)))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/hunkyburrito/xdg-desktop-portal-termfilechooser")
    (synopsis "Terminal file chooser portal")
    (description "XDG Desktop Portal backend for terminal file choosers.")
    (license expat)))

xdg-desktop-portal-termfilechooser
