(define-module (custom packages wl)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses)
  #:use-module (gnu packages elf)
  #:use-module (gnu packages base)
  #:use-module (gnu packages compression)
  #:use-module (guix gexp))

(define-public wl
  (package
    (name "wl")
    (version "0.1.0")
    (source (local-file "wl-binaries.tar.gz"
              #:recursive? #f))
    (build-system gnu-build-system)
    (native-inputs (list patchelf tar gzip))
    (arguments
     `(#:tests? #f
       #:strip-binaries? #f
       #:validate-runpath? #f
       #:phases
       (modify-phases %standard-phases
         (delete 'bootstrap)
         (delete 'configure)
         (delete 'check)
         (delete 'build)
         (delete 'patch-usr-bin-file)
         (delete 'patch-source-shebangs)
         (delete 'patch-generated-file-shebangs)
         (replace 'install
           (lambda* (#:key outputs inputs #:allow-other-keys)
             (let* ((out    (assoc-ref outputs "out"))
                    (bdir   (string-append out "/bin"))
                    (glibc  (assoc-ref %build-inputs "libc"))
                    (interp (string-append glibc "/lib/ld-linux-x86-64.so.2"))
                    (pe     (string-append (assoc-ref inputs "patchelf")
                                           "/bin/patchelf")))
               (mkdir-p bdir)
               (for-each
                 (lambda (bin)
                   (install-file bin bdir)
                   (chmod (string-append bdir "/" bin) #o555)
                   (false-if-exception
                     (invoke pe "--set-interpreter" interp
                             (string-append bdir "/" bin))))
                 '("wl" "wl-daemon"))
               #t))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/neg-serg/wl")
    (synopsis "Wayland wallpaper daemon with Vulkan backend")
    (description "Fork of swww with Vulkan backend for Wayland wallpaper management.")
    (license gpl3+)))

wl
