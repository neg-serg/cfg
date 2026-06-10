(define-module (custom packages hishtory)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses))

(define-public hishtory
  (package
    (name "hishtory")
    (version "0.335")
    (source (origin
              (method url-fetch)
              (uri "https://github.com/ddworken/hishtory/releases/download/v0.335/hishtory-linux-amd64")
              (sha256 (base32 "0wfjw8xjxg1y5vrm6p3b461ghv29j7hhsrzmbsyc1w20rpp2daa9"))))
    (build-system gnu-build-system)
    (arguments
     '(#:tests? #f #:strip-binaries? #f #:validate-runpath? #f
       #:phases (modify-phases %standard-phases
         (delete 'bootstrap) (delete 'configure) (delete 'check) (delete 'build)
         (delete 'patch-usr-bin-file) (delete 'patch-source-shebangs)
         (delete 'patch-generated-file-shebangs)
         (replace 'unpack
           (lambda* (#:key source #:allow-other-keys)
             (symlink source "hishtory-linux-amd64")
             #t))
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (let* ((out (assoc-ref outputs "out"))
                    (bin (string-append out "/bin")))
               (mkdir-p bin)
               (copy-file "hishtory-linux-amd64" (string-append bin "/hishtory"))
               (chmod (string-append bin "/hishtory") #o755))
             #t)))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://hishtory.dev")
    (synopsis "Shell history sync")
    (description "Seamless shell history sync across devices.")
    (license expat)))

hishtory
