(define-module (custom services tailscale)
  #:use-module (gnu services)
  #:use-module (gnu services shepherd)
  #:use-module (custom packages tailscale)
  #:use-module (guix gexp)
  #:export (tailscale-shepherd-service))

(define tailscale-shepherd-service
  (shepherd-service
    (provision '(tailscaled tailscale))
    (requirement '(networking))
    (start #~(make-forkexec-constructor
              (list #$(file-append tailscale "/bin/tailscaled")
                    "--state=/var/lib/tailscale/tailscaled.state"
                    "--socket=/run/tailscale/tailscaled.sock"
                    "--port=41641")
              #:log-file "/var/log/tailscaled.log"))
    (stop #~(make-kill-destructor))
    (auto-start? #f)))
