(define-module (custom services mpd)
  #:use-module (gnu services)
  #:use-module (gnu services shepherd)
  #:use-module (gnu packages mpd)
  #:use-module (guix gexp)
  #:export (mpd-shepherd-service))

(define mpd-shepherd-service
  (shepherd-service
    (provision '(mpd))
    (requirement '(user-processes networking))
    (start #~(make-forkexec-constructor
              (list #$(file-append mpd "/bin/mpd")
                    "--no-daemon"
                    "/home/guest/.config/mpd/mpd.conf")
              #:log-file "/var/log/mpd.log"))
    (stop #~(make-kill-destructor))
    (auto-start? #f)))
