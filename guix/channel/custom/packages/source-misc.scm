(define-module (custom packages source-misc)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system cmake)
  #:use-module (guix licenses)
  #:use-module (gnu packages cmake)
  #:use-module (gnu packages perl))

;; fortune-mod — minimal build from tarball (try cmake)
(define-public fortune-mod
  (package
    (name "fortune-mod")
    (version "3.26.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "https://github.com/shlomif/fortune-mod/releases/download/"
                    "fortune-mod-" version "/fortune-mod-" version ".tar.xz"))
              (sha256 (base32 "0k7ypxj3gi24n4swc3n0x958msbg22a6n4q7j429kff9ra318kdc"))))
    (build-system cmake-build-system)
    (native-inputs (list perl perl-path-tiny))
    (arguments
     '(#:tests? #f
       #:phases
       (modify-phases %standard-phases
         (add-before 'build 'skip-man-pages
           (lambda* (#:key outputs #:allow-other-keys)
             (let ((src (car (find-files ".." "^fortune-mod-"
                                         #:directories? #t))))
               ;; Create placeholder files so cmake skips man page generation
               ;; (requires CPAN modules not packaged in Guix)
               (for-each (lambda (f)
                           (let ((path (string-append src "/" f)))
                             (unless (file-exists? path)
                               (with-output-to-file path
                                 (lambda () (display ""))))))
                         '("fortune/fortune_with_offensive.docbook5.xml"
                           "fortune/fortune_with_offensive.template.man"
                           "fortune/fortune_without_offensive.docbook5.xml"
                           "fortune/fortune_without_offensive.template.man"
                           "util/strfile.man"
                           "util/randstr.man")))
             (unless (file-exists? "manpages/fortune.6")
               (mkdir-p "manpages")
               (with-output-to-file "manpages/fortune.6"
                 (lambda () (display ""))))
             #t)))))
    (home-page "https://github.com/shlomif/fortune-mod")
    (synopsis "Fortune cookie generator")
    (description "Fortune-mod prints random fortune cookies.")
    (license gpl3+)))

fortune-mod
