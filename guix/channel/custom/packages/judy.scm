(define-module (custom packages judy)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module ((guix licenses) #:prefix license:))

(define-public judy
  (package
    (name "judy")
    (version "1.0.5")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "https://downloads.sourceforge.net/project/judy/judy/Judy-"
                    version "/Judy-" version ".tar.gz"))
              (sha256
               (base32 "1sv3990vsx8hrza1mvq3bhvv9m6ff08y4yz7swn6znszz24l0w6j"))))
    (build-system gnu-build-system)
    (arguments
     '(#:tests? #f
       #:phases (modify-phases %standard-phases
                  (add-before 'configure 'set-cflags
                    (lambda _
                      (setenv "CFLAGS" "-fPIC")
                      #t))
                  (add-after 'configure 'fix-makefiles
                    (lambda _
                      (substitute* "Makefile"
                        (("^SUBDIRS =.*") "SUBDIRS = src tool\n"))
                      (substitute* "src/Makefile"
                        (("^SUBDIRS =.*")
                         "SUBDIRS = JudyCommon JudyL Judy1 JudySL JudyHS obj\n"))
                      #t)))))
    (home-page "https://sourceforge.net/projects/judy/")
    (synopsis "C library that implements a sparse dynamic array")
    (description "Judy is a C library that provides a state-of-the-art core
technology that implements a sparse dynamic array.  Judy arrays are fast,
memory efficient, and scale well.")
    (license license:lgpl2.1+)))

judy
