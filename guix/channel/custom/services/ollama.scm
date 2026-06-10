(define-module (custom services ollama)
  #:use-module (gnu services)
  #:use-module (gnu services shepherd)
  #:use-module (custom packages ollama)
  #:use-module (guix gexp)
  #:export (ollama-shepherd-service))

(define ollama-shepherd-service
  (shepherd-service
    (provision '(ollama))
    (requirement '(networking))
    (start #~(make-forkexec-constructor
              (list #$(file-append ollama "/bin/ollama") "serve")
              #:log-file "/var/log/ollama.log"))
    (stop #~(make-kill-destructor))
    (auto-start? #f)))
