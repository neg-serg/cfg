(define-module (custom packages oports)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system trivial)
  #:use-module (guix licenses))

(define-public oports
  (package
    (name "oports")
    (version "1.0")
    (source (origin
              (method url-fetch)
              (uri "https://raw.githubusercontent.com/sdushantha/oports/master/oports")
              (sha256 (base32 "0wijpjbg3hkzgmg0sd850m50sb3lpx2cjalfablf3dv73vhfqkq5"))))
    (build-system trivial-build-system)
    (arguments
     '(#:modules ((guix build utils))
       #:builder
       (begin
         (use-modules (guix build utils))
         (let* ((source (assoc-ref %build-inputs "source"))
                (out (assoc-ref %outputs "out"))
                (bin (string-append out "/bin")))
           (mkdir-p bin)
           (copy-file source (string-append bin "/oports"))
           (chmod (string-append bin "/oports") #o555)))))
    (home-page "https://github.com/sdushantha/oports")
    (synopsis "Port scanner")
    (description "Fast port scanner written in bash.")
    (license gpl3+)))

oports
