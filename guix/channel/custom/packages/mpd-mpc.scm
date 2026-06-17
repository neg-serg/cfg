(define-module (custom packages mpd-mpc)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix build-system trivial)
  #:use-module ((guix licenses) #:prefix license:))

;; The MPD client 'mpc' conflicts with math library 'mpc' in the profile.
;; This is a wrapper that provides the mpd-mpc binary with a symlink at 'mpc-cli'.
(define-public mpd-mpc
  (let ((mpg (@ (gnu packages mpd) mpd-mpc)))
    (package
      (name "mpd-mpc")
      (version (package-version mpg))
      (source #f)
      (build-system trivial-build-system)
      (inputs (list mpg))
      (arguments
       (list #:modules '((guix build utils))
             #:builder
             #~(begin
                 (use-modules (guix build utils))
                 (let* ((out #$output)
                        (bin (string-append out "/bin"))
                        (mpd-mpc-in #$(file-append mpg "/bin/mpc")))
                   (mkdir-p bin)
                   (symlink mpd-mpc-in (string-append bin "/mpc"))
                   (symlink mpd-mpc-in (string-append bin "/mpc-cli"))))))
      (home-page "https://www.musicpd.org/clients/mpc/")
      (synopsis "Music Player Daemon client")
      (description "MPC is a minimalist command line interface to MPD, the music
player daemon.")
      (license license:gpl2))))

mpd-mpc
