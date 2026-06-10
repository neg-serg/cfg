(define-module (custom packages ananicy-cpp)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses)
  #:use-module (gnu packages compression))

(define-public ananicy-cpp
  (package
    (name "ananicy-cpp")
    (version "1.2.0")
    (source
      (origin
        (method url-fetch)
        (uri (string-append
               "https://gitlab.com/api/v4/projects/"
               "ananicy-cpp%2Fananicy-cpp/jobs/artifacts/"
               "v1.2.0/download?job=build"))
        (file-name (string-append name "-" version ".zip"))
        (sha256
          (base32 "1i277v55dmbs8j1n3qlc2zcqhlsn6vpkzpcpck6h2dz6y5y73qca"))))
    (build-system gnu-build-system)
    (native-inputs (list unzip))
    (home-page "https://gitlab.com/ananicy-cpp/ananicy-cpp")
    (synopsis "Auto nice daemon for better desktop responsiveness")
    (description "Ananicy is a daemon that manages processes'
IO and CPU priority automatically using rules.")
    (license gpl3+)
    (arguments
     '(#:tests? #f
       #:phases (modify-phases %standard-phases
         (replace 'unpack
           (lambda* (#:key source #:allow-other-keys)
             (invoke "unzip" source)
             #t))
         (delete 'bootstrap)
         (delete 'configure)
         (delete 'check)
         (delete 'build)
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (let* ((out (assoc-ref outputs "out"))
                    (bin (string-append out "/bin")))
               (mkdir-p bin)
               (install-file "build/ananicy-cpp" bin)
               #t))))))))

ananicy-cpp
