(define-module (custom packages zen-browser)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses)
  #:use-module (gnu packages elf))

(define-public zen-browser
  (package
    (name "zen-browser")
    (version "1.19.13b")
    (source
      (origin
        (method url-fetch)
        (uri (string-append
               "https://github.com/zen-browser/desktop/releases/download/"
               "1.19.13b" "/zen.linux-x86_64.tar.xz"))
        (sha256
          (base32
            "006rw5qpaigqkj73ry16m9xmd45ibi6gzxk0ba9vyvac8kxrziyz"))))
    (build-system gnu-build-system)
    (native-inputs (list patchelf))
    (arguments
     '(#:tests? #f
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
             (let* ((out     (assoc-ref outputs "out"))
                    (zendir  (string-append out "/zen"))
                    (bin     (string-append out "/bin"))
                    (glibc   (assoc-ref %build-inputs "libc"))
                    (interp  (string-append glibc
                                     "/lib/ld-linux-x86-64.so.2"))
                    (pe      (string-append
                              (assoc-ref %build-inputs "patchelf")
                              "/bin/patchelf")))
                (mkdir-p bin)
                (copy-recursively "." (string-append out "/zen"))
                (symlink (string-append out "/zen/zen")
                         (string-append bin "/zen"))
                (false-if-exception
                 (invoke pe "--set-interpreter" interp
                         (string-append out "/zen/zen")))
               #t))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://zen-browser.app")
    (synopsis "Privacy-focused Firefox-based browser")
    (description "Zen Browser is a privacy-focused browser based on Firefox.")
    (license mpl2.0)))

zen-browser
