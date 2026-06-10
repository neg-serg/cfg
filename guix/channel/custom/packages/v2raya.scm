(define-module (custom packages v2raya)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses)
  #:use-module (gnu packages elf))

(define-public v2raya
  (package
    (name "v2raya")
    (version "2.2.7.5")
    (source
      (origin
        (method url-fetch)
        (uri (string-append
               "https://github.com/v2rayA/v2rayA/releases/download/v"
               "2.2.7.5" "/v2raya_linux_x64_2.2.7.5"))
        (sha256
          (base32
            "0csxspkhq1glsyljngqjqcri4qivd03b74qkirmb088gxr71zg1k"))))
    (build-system gnu-build-system)
    (native-inputs (list patchelf))
    (arguments
     '(#:tests? #f
       #:strip-binaries? #f
       #:validate-runpath? #f
       #:phases (modify-phases %standard-phases
         (replace 'unpack
           (lambda* (#:key source #:allow-other-keys)
             (symlink source "v2raya_linux_x64_2.2.7.5")
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
             (let* ((out    (assoc-ref outputs "out"))
                    (bin    (string-append out "/bin"))
                    (glibc  (assoc-ref %build-inputs "libc"))
                    (interp (string-append glibc
                                    "/lib/ld-linux-x86-64.so.2"))
                    (pe     (string-append
                             (assoc-ref %build-inputs "patchelf")
                             "/bin/patchelf")))
               (mkdir-p bin)
               (copy-file "v2raya_linux_x64_2.2.7.5"
                          (string-append bin "/v2raya"))
               (chmod (string-append bin "/v2raya") #o555)
               (false-if-exception
                (invoke pe "--set-interpreter" interp
                        (string-append bin "/v2raya")))
               #t))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/v2rayA/v2rayA")
    (synopsis "V2Ray web frontend")
    (description "Web GUI for managing V2Ray.")
    (license agpl3+)))

v2raya
