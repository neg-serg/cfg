(define-module (custom packages mpd-mpc)
  #:use-module (guix packages)
  #:use-module (gnu packages mpd)
  #:use-module ((guix licenses) #:prefix license:))

;; The MPD client 'mpc' conflicts with math library 'mpc' in the profile.
;; This package provides the same binary under a unique name via 'mpc-cli'.
(define-public mpd-mpc
  (package
    (inherit mpc)
    (name "mpd-mpc")
    (arguments
     (substitute-keyword-arguments (package-arguments mpc)
       ((#:phases phases)
        `(modify-phases ,phases
           (add-after 'install 'rename-binary
             (lambda* (#:key outputs #:allow-other-keys)
               (let* ((out (assoc-ref outputs "out"))
                      (bin (string-append out "/bin")))
                 (rename-file (string-append bin "/mpc")
                              (string-append bin "/mpc-cli"))
                 (symlink (string-append bin "/mpc-cli")
                          (string-append bin "/mpc")))
               #t))))))))

mpd-mpc
