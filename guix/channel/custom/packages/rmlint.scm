(define-module (custom packages rmlint)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses)
  #:use-module (gnu packages python)
  #:use-module (gnu packages build-tools)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages glib)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages sphinx))

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
               (sha256 (base32 "1033h99z443wqb66rrh34gmnlnlbjsm5j1sqpg069jdih2ffi6a3"))))
    (build-system gnu-build-system)
    (inputs (list glib `(,util-linux "lib")))
    (native-inputs (list linux-libre-headers python python-sphinx pkg-config scons))
    (arguments
     '(#:tests? #f
       #:phases (modify-phases %standard-phases
         (delete 'bootstrap)
         (delete 'configure)
         (delete 'check)
         (delete 'build)
         (delete 'install)
           (add-after 'unpack 'build
            (lambda* (#:key inputs #:allow-other-keys)
              (setenv "CFLAGS"
                      (string-append "-I"
                                     (assoc-ref inputs "linux-libre-headers")
                                     "/include"
                                     " -I"
                                     (assoc-ref inputs "util-linux")
                                     "/include"))
              (invoke "scons" "--without-gui" "-j" (number->string (parallel-job-count)))))
          (add-after 'build 'install
            (lambda* (#:key outputs #:allow-other-keys)
              (invoke "scons" "--without-gui"
                      (string-append "--prefix=" (assoc-ref outputs "out"))
                       "install"))))))
    (home-page "https://github.com/sahib/rmlint")
    (synopsis "Extremely fast duplicate file finder")
    (description "rmlint finds space waste and other broken things on your
filesystem and offers to remove it.")
    (license gpl3+)))
 
 rmlint
