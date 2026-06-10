(define-module (custom packages optiscaler)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses))

(define-public optiscaler
  (package
    (name "optiscaler")
    (version "2.0.0")
    (source (origin
              (method url-fetch)
              (uri "https://github.com/ind4skylivey/0ptiscaler4linux/archive/refs/tags/v2.0.0.tar.gz")
              (sha256 (base32 "1k6i7zsyvr7xz1xzbqf7920fash4ac6v184ybyv6qdm1w5hiznza"))))
    (build-system gnu-build-system)
    (arguments
     '(#:tests? #f #:strip-binaries? #f #:validate-runpath? #f #:patch-shebangs? #f
       #:phases (modify-phases %standard-phases
                  (delete 'bootstrap) (delete 'configure) (delete 'check)
                  (delete 'build) (delete 'patch-usr-bin-file)
                  (delete 'patch-source-shebangs)
                  (delete 'patch-generated-file-shebangs)
                  (add-after 'unpack 'fix-shebang
                    (lambda _
                      (substitute* (find-files "." "^install\\.sh$")
                        (("/bin/bash") (which "bash")))
                      #t))
                  (replace 'install
                    (lambda* (#:key outputs #:allow-other-keys)
                      (let* ((out (assoc-ref outputs "out"))
                             (bin (string-append out "/bin"))
                             (script (car (find-files "." "^install\\.sh$"))))
                        (mkdir-p bin)
                        (copy-file script (string-append bin "/optiscaler"))
                        (chmod (string-append bin "/optiscaler") #o555)
                        (for-each
                          (lambda (d)
                            (copy-recursively d
                              (string-append out "/" (basename d))))
                          (list "binaries" "config" "core" "docs"
                                "lib" "profiles" "scripts" "src"
                                "templates" "tests" "vendor"))
                        #t))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/ind4skylivey/0ptiscaler4linux")
    (synopsis "OptiScaler installer for Linux")
    (description "Bash script to install and configure OptiScaler, a DirectX-to-Vulkan upscaling wrapper.")
    (license expat)))

optiscaler
