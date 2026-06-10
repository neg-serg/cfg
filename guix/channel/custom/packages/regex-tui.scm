(define-module (custom packages regex-tui)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses)
  #:use-module (gnu packages elf))

(define-public regex-tui
  (package
    (name "regex-tui")
    (version "0.7.0")
    (source (origin
              (method url-fetch)
              (uri "https://github.com/vitor-mariano/regex-tui/releases/download/v0.7.0/regex-tui_v0.7.0_linux.amd64")
              (sha256 (base32 "0c0p0r942k8war505yxs5rha7c283r5dqz6c8yfwj6ic0iklw6k9"))))
    (build-system gnu-build-system)
    (inputs (list patchelf))
    (arguments
     '(#:tests? #f #:strip-binaries? #f #:validate-runpath? #f
       #:phases (modify-phases %standard-phases
                  (delete 'bootstrap) (delete 'configure) (delete 'check)
                  (delete 'build) (delete 'patch-usr-bin-file)
                  (delete 'patch-source-shebangs)
                  (delete 'patch-generated-file-shebangs)
                  (add-after 'unpack 'fix-perms
                    (lambda* (#:key inputs outputs #:allow-other-keys)
                      (let* ((glibc (assoc-ref inputs "libc"))
                             (interp (string-append glibc "/lib/ld-linux-x86-64.so.2"))
                             (pe (string-append (assoc-ref inputs "patchelf")
                                               "/bin/patchelf"))
                             (script (car (find-files "." "^regex-tui")))
                             (bin (string-append (assoc-ref outputs "out")
                                                 "/bin")))
                        (mkdir-p bin)
                        (chmod script #o755)
                        (invoke pe "--set-interpreter" interp script)
                        (copy-file script (string-append bin "/regex-tui"))
                        #t)))
                  (replace 'install
                    (lambda* (#:key outputs #:allow-other-keys)
                      #t)))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/vitor-mariano/regex-tui")
    (synopsis "TUI to visualize regular expressions")
    (description "Simple TUI to visualize regular expressions in the terminal.")
    (license expat)))

regex-tui
