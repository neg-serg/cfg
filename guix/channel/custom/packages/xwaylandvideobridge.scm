(define-module (custom packages xwaylandvideobridge)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses)
  #:use-module (gnu packages elf))

(define-public xwaylandvideobridge
  (let ((bin (local-file "xwaylandvideobridge.bin")))
    (package
      (name "xwaylandvideobridge")
      (version "0.1.0")
      (source bin)
      (build-system gnu-build-system)
      (native-inputs (list patchelf))
      (arguments
       '(#:tests? #f #:strip-binaries? #f #:validate-runpath? #f
         #:phases (modify-phases %standard-phases
           (replace 'unpack
             (lambda* (#:key source #:allow-other-keys)
               (symlink source "xwaylandvideobridge")
               #t))
           (delete 'bootstrap) (delete 'configure) (delete 'check)
           (delete 'build) (delete 'patch-usr-bin-file)
           (delete 'patch-source-shebangs) (delete 'patch-generated-file-shebangs)
           (replace 'install
             (lambda* (#:key outputs #:allow-other-keys)
               (let* ((out  (assoc-ref outputs "out"))
                      (bdir  (string-append out "/bin"))
                      (glibc (assoc-ref %build-inputs "libc"))
                      (interp (string-append glibc "/lib/ld-linux-x86-64.so.2"))
                      (pe  (string-append (assoc-ref %build-inputs "patchelf")
                                          "/bin/patchelf")))
                 (mkdir-p bdir)
                 (install-file "xwaylandvideobridge" bdir)
                 (chmod (string-append bdir "/xwaylandvideobridge") #o755)
                 (false-if-exception
                  (invoke pe "--set-interpreter" interp
                          (string-append bdir "/xwaylandvideobridge")))
                 #t))))))
      (supported-systems '("x86_64-linux"))
      (home-page "")
      (synopsis "xwaylandvideobridge — ported from Arch")
      (description "")
      (license gpl3+))))

xwaylandvideobridge
