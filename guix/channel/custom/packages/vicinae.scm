(define-module (custom packages vicinae)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses)
  #:use-module (gnu packages elf))

;; NOTE: vicinae is a custom Qt6 launcher built separately.
;; Place the built binary at guix/channel/custom/packages/vicinae.bin
;; or override source with a GitHub release URL.
;; To build from source, use git-fetch from https://github.com/neg-serg/vicinae

(define %vicinae-bin-url
  ;; Replace with actual release URL when available
  "https://github.com/neg-serg/vicinae/releases/download/v0.1.0/vicinae")

(define-public vicinae
  (package
    (name "vicinae")
    (version "0.1.0")
    (source (origin
              (method url-fetch)
              (uri %vicinae-bin-url)
              ;; FIXME: replace with actual hash after first build
              (sha256 (base32
                       "0000000000000000000000000000000000000000000000000000"))))
    (build-system gnu-build-system)
    (native-inputs (list patchelf))
    (arguments
     '(#:tests? #f
       #:strip-binaries? #f
       #:validate-runpath? #f
       #:phases (modify-phases %standard-phases
         (replace 'unpack
           (lambda* (#:key source #:allow-other-keys)
             (symlink source "vicinae")
             #t))
         (delete 'bootstrap)
         (delete 'configure)
         (delete 'check)
         (delete 'build)
         (delete 'patch-usr-bin-file)
         (delete 'patch-source-shebangs)
         (delete 'patch-generated-file-shebangs)
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (let* ((out  (assoc-ref outputs "out"))
                    (bin  (string-append out "/bin"))
                    (glibc (assoc-ref %build-inputs "libc"))
                    (interp (string-append glibc "/lib/ld-linux-x86-64.so.2"))
                    (pe (string-append (assoc-ref %build-inputs "patchelf")
                                       "/bin/patchelf")))
               (mkdir-p bin)
               (install-file "vicinae" bin)
               (chmod (string-append bin "/vicinae") #o755)
               (invoke pe "--set-interpreter" interp
                       (string-append bin "/vicinae"))
               #t))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/neg-serg/vicinae")
    (synopsis "Application launcher")
    (description "Qt6-based application launcher.")
    (license gpl3+)))
