(define-module (custom packages chawan)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses)
  #:use-module (gnu packages)
  #:use-module (gnu packages nim)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages ssh)
  #:use-module (gnu packages tls)
  #:use-module (gnu packages curl)
  #:use-module (gnu packages bash))

(define-public chawan
  (package
    (name "chawan")
    (version "0.4.1")
    (source (origin
              (method git-fetch)
              (uri (git-reference
                    (url "https://git.sr.ht/~bptato/chawan")
                    (commit (string-append "v" version))))
              (file-name (git-file-name name version))
               (sha256
                (base32
                 "0b5vkq3i7r5ar66wiwv6kpy2wfgnvv0jlky42v4qrcldbwhf02fg"))))
    (build-system gnu-build-system)
    (arguments
     '(#:tests? #f
       #:phases (modify-phases %standard-phases
         (delete 'configure)
         (replace 'build
           (lambda* (#:key outputs #:allow-other-keys)
             (invoke "make" (string-append "LIBEXECDIR="
                                           (assoc-ref outputs "out")
                                           "/lib/chawan"))))
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (let* ((out (assoc-ref outputs "out"))
                    (bin (string-append out "/bin"))
                    (libexec (string-append out "/lib/chawan"))
                    (share (string-append out "/share")))
               (mkdir-p bin)
               (mkdir-p libexec)
               (mkdir-p (string-append share "/man/man1"))
               (mkdir-p (string-append share "/man/man5"))
               (copy-recursively "src" libexec)
               (symlink (string-append libexec "/cha/cha")
                        (string-append bin "/cha"))
               (for-each
                (lambda (f)
                  (install-file f (string-append share "/man/man1")))
                (find-files "doc" "\\.1$"))
               (for-each
                (lambda (f)
                  (install-file f (string-append share "/man/man5")))
                (find-files "doc" "\\.5$"))))))))
    (native-inputs (list nim bash-minimal))
    (inputs (list brotli libssh2 openssl curl))
    (home-page "https://chawan.net/")
    (synopsis "Text-mode web browser and pager")
    (description
     "Chawan is a text-mode web browser and pager for Unix-like systems.
It supports HTML rendering, CSS styling, and JavaScript execution
in a terminal environment.")
    (license unlicense)))
