(define-module (custom packages proxypilot)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses)
  #:use-module (gnu packages elf))

(define-public proxypilot
  (package
    (name "proxypilot")
    (version "0.3.0-dev-0.62")
    (source
      (origin
        (method url-fetch)
        (uri (string-append
               "https://github.com/Finesssee/ProxyPilot/releases/download/v"
               "0.3.0-dev-0.62" "/proxypilot-linux-amd64"))
        (sha256
          (base32
            "16iglv6ipcwg53ccyr5gdrq848hsq6s87n9l9jv977r4sp94h7fv"))))
    (build-system gnu-build-system)
    (native-inputs (list patchelf))
    (arguments
     '(#:tests? #f
       #:strip-binaries? #f
       #:validate-runpath? #f
       #:phases (modify-phases %standard-phases
         (replace 'unpack
           (lambda* (#:key source #:allow-other-keys)
             (symlink source "proxypilot-linux-amd64")
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
               (copy-file "proxypilot-linux-amd64"
                          (string-append bin "/proxypilot"))
               (chmod (string-append bin "/proxypilot") #o555)
               (false-if-exception
                (invoke pe "--set-interpreter" interp
                        (string-append bin "/proxypilot")))
               #t))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/Finesssee/ProxyPilot")
    (synopsis "Proxy management tool")
    (description "Proxy management and switching tool.")
    (license gpl3+)))

proxypilot
