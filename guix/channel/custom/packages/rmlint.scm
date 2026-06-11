(define-module (custom packages rmlint)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses)
  #:use-module (gnu packages python)
  #:use-module (gnu packages build-tools))

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
               (sha256 (base32 "0gn3h2hns1r74xphbhasnj2z0ipsss87wjammqbqfp6i15fvvzcg"))))
    (build-system gnu-build-system)
    (native-inputs (list python scons))
    (arguments
     '(#:tests? #f
       #:phases (modify-phases %standard-phases
         (delete 'bootstrap)
         (delete 'configure)
         (delete 'check)
         (delete 'build)
         (delete 'install)
         (add-after 'unpack 'build
           (lambda _
             (invoke "scons" "-j" (number->string (parallel-job-count)))))
         (add-after 'build 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (invoke "scons" (string-append "PREFIX=" (assoc-ref outputs "out"))
                      "install"))))))
    (home-page "https://github.com/sahib/rmlint")
    (synopsis "Extremely fast duplicate file finder")
    (description "rmlint finds space waste and other broken things on your
filesystem and offers to remove it.")
    (license gpl3+)))
 
 rmlint
