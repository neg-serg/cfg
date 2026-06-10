(define-module (custom packages source-ioping)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses)
  #:use-module (gnu packages base))

(define-public ioping
  (package
    (name "ioping")
    (version "1.3")
    (source (origin
              (method git-fetch)
              (uri (git-reference
                    (url "https://github.com/koct9i/ioping")
                    (commit (string-append "v" version))))
              (file-name (git-file-name name version))
              (sha256 (base32 "0jznf9zm0y8jgkg8pv78vqqwdgigl3jmv6cx4ghdidiwgf748lpn"))))
    (build-system gnu-build-system)
    (arguments
     '(#:tests? #f
       #:phases (modify-phases %standard-phases
         (delete 'bootstrap)
         (delete 'configure)
         (replace 'build
           (lambda _
             (invoke "gcc" "-Wall" "-O2" "-o" "ioping" "ioping.c" "-lm")
             #t))
         (replace 'check
           (lambda _
             (invoke "./ioping" "-c" "1" ".")
             #t))
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (let ((bin (string-append (assoc-ref outputs "out") "/bin")))
               (mkdir-p bin)
               (install-file "ioping" bin)
               #t))))))
    (home-page "https://github.com/koct9i/ioping")
    (synopsis "Disk I/O latency monitor")
    (description "ioping monitors disk I/O latency in real time.")
    (license gpl3+)))

ioping
