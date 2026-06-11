(define-module (custom packages rmlint)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses)
  #:use-module (gnu packages python))

(define-public rmlint
  (package
    (name "rmlint")
    (version "2.10.3")
    (source (origin
              (method git-fetch)
              (uri (git-reference
                    (url "https://github.com/sahib/rmlint")
                    (commit (string-append "v" version))))
              (file-name (git-file-name name version))
               (sha256 (base32 "r7632xij2foiof5okvex5egw7jdpbbnullaqk3zhe4dw3imaym7a"))))
    (build-system gnu-build-system)
    (native-inputs (list python python-scons))
    (arguments
     '(#:tests? #f
       #:phases (modify-phases %standard-phases
         (delete 'bootstrap)
         (delete 'configure)
         (delete 'check)
         (replace 'build
           (lambda _
             (invoke "scons" "-j" (number->string (parallel-job-count)))
             #t))
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (invoke "scons" (string-append "PREFIX=" (assoc-ref outputs "out"))
                     "install")
             #t))))))
    (home-page "https://github.com/sahib/rmlint")
    (synopsis "Extremely fast duplicate file finder")
    (description "rmlint finds space waste and other broken things on your
filesystem and offers to remove it.")
    (license gpl3+)))

rmlint
