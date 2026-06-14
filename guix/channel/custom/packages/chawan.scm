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
  #:use-module (gnu packages bash)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages commencement))

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
                 "19znbjwvw6k83ra75f1q0y2x13nifyifq5jnppxcg1fbsjrls0vq"))))
    (build-system gnu-build-system)
    (arguments
     '(#:tests? #f
       #:phases (modify-phases %standard-phases
         (delete 'configure)
         (replace 'build
           (lambda* (#:key outputs #:allow-other-keys)
             (setenv "HOME" "/tmp")
             (let ((libexec (string-append (assoc-ref outputs "out")
                                           "/lib/chawan")))
               (invoke "make" "CC=gcc" "AR=ar"
                       (string-append "PREFIX=" (assoc-ref outputs "out"))
                       (string-append "LIBEXECDIR=" libexec)))))
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (let ((out (assoc-ref outputs "out")))
               (invoke "make" "install"
                       (string-append "PREFIX=" out)
                       (string-append "LIBEXECDIR=" out "/lib/chawan")
                       "DESTDIR=")))))))
    (native-inputs (list nim bash-minimal pkg-config gcc-toolchain))
    (inputs (list brotli libssh2 openssl curl))
    (home-page "https://chawan.net/")
    (synopsis "Text-mode web browser and pager")
    (description
     "Chawan is a text-mode web browser and pager for Unix-like systems.
It supports HTML rendering, CSS styling, and JavaScript execution
in a terminal environment.")
    (license unlicense)))
