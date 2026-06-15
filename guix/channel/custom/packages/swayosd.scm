(define-module (custom packages swayosd)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses)
  #:use-module (gnu packages base)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages elf))

(define %swayosd-tarball
  (local-file "swayosd-binaries.tar.gz"
              #:recursive? #f))

(define-public swayosd
  (package
    (name "swayosd")
    (version "0.3.1")
    (source %swayosd-tarball)
    (build-system gnu-build-system)
    (native-inputs (list tar gzip patchelf))
    (arguments
     `(#:tests? #f
       #:strip-binaries? #f
       #:validate-runpath? #f
       #:phases (modify-phases %standard-phases
                  (delete 'bootstrap)
                  (delete 'configure)
                  (delete 'check)
                  (delete 'build)
                  (delete 'patch-usr-bin-file)
                  (delete 'patch-source-shebangs)
                  (delete 'patch-generated-file-shebangs)
                  (replace 'install
                    (lambda* (#:key outputs #:allow-other-keys)
                      (let* ((out (assoc-ref outputs "out"))
                             (bin (string-append out "/bin"))
                             (glibc (assoc-ref %build-inputs "libc"))
                             (interp (string-append glibc "/lib/ld-linux-x86-64.so.2"))
                             (pe (string-append (assoc-ref %build-inputs "patchelf")
                                                "/bin/patchelf")))
                        (mkdir-p bin)
                        (for-each (lambda (f)
                                    (install-file f bin)
                                    (false-if-exception
                                     (invoke pe "--set-interpreter" interp
                                             (string-append bin "/" f))))
                                  '("swayosd-server" "swayosd-client"))
                        #t))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/ErikReider/SwayOSD")
    (synopsis "OSD window for Sway and other Wayland compositors")
    (description "SwayOSD provides on-screen display (OSD) windows for
brightness, volume, and keyboard layout changes on Sway and similar
wlroots-based Wayland compositors.")
    (license gpl3+)))

swayosd
