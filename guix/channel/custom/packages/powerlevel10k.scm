(define-module (custom packages powerlevel10k)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses)
  #:use-module (gnu packages base)
  #:use-module (gnu packages shells))

(define-public powerlevel10k
  (package
    (name "powerlevel10k")
    (version "1.20.0")
    (source (origin
              (method git-fetch)
              (uri (git-reference
                    (url "https://github.com/romkatv/powerlevel10k")
                    (commit (string-append "v" version))))
              (file-name (git-file-name name version))
              (sha256
               (base32
                "1ha7qb601mk97lxvcj9dmbypwx7z5v0b7mkqahzsq073f4jnybhi"))))
    (build-system gnu-build-system)
    (arguments
     '(#:tests? #f
       #:phases (modify-phases %standard-phases
         (delete 'bootstrap)
         (delete 'configure)
         (delete 'check)
         (delete 'build)
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (let* ((out (assoc-ref outputs "out"))
                    (share (string-append out "/share/zsh/powerlevel10k")))
               (mkdir-p share)
               (copy-recursively "." share)
               #t))))))
    (home-page "https://github.com/romkatv/powerlevel10k")
    (synopsis "Zsh theme with focus on speed, flexibility, and usability")
    (description "Powerlevel10k is a theme for Zsh.  It emphasizes speed,
flexibility, and out-of-the-box experience.")
    (license expat)))

powerlevel10k
