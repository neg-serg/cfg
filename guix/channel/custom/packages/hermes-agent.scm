(define-module (custom packages hermes-agent)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system trivial)
  #:use-module (guix licenses)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages base))

(define-public hermes-agent
  (package
    (name "hermes-agent")
    (version "1.6")
    (source
      (origin
        (method url-fetch)
        (uri (string-append
               "https://github.com/ralt/hermes/releases/download/"
               version "/hermes_" version "_amd64.deb"))
        (sha256
          (base32
            "06n8blg2ylr0gm04i3ijyar2yg9bss2z8ibd9466f83fgpz0kc7h"))))
    (build-system trivial-build-system)
    (arguments
     `(#:modules ((guix build utils))
       #:builder
       (begin
         (use-modules (guix build utils))
         (let* ((source (assoc-ref %build-inputs "source"))
                (out    (assoc-ref %outputs "out"))
                (bin    (string-append out "/bin"))
                (sbin   (string-append out "/sbin"))
                (lib    (string-append out "/lib/security")))
           (mkdir-p bin)
           (mkdir-p sbin)
           (mkdir-p lib)
           (setenv "PATH" (string-append
                          (assoc-ref %build-inputs "binutils") "/bin:"
                          (assoc-ref %build-inputs "tar") "/bin:"
                          (assoc-ref %build-inputs "xz") "/bin"))
         (invoke "ar" "x" source)
           (invoke "tar" "xf" "data.tar.xz")
            (copy-file "usr/bin/hermes"
                       (string-append bin "/hermes-agent"))
            (chmod (string-append bin "/hermes-agent") #o555)
            (copy-file "usr/share/hermes/hermes-daemon"
                       (string-append sbin "/hermes-agent-daemon"))
            (chmod (string-append sbin "/hermes-agent-daemon") #o555)
            (copy-file "lib/security/pam_hermes.so"
                       (string-append lib "/pam_hermes-agent.so"))
            (chmod (string-append lib "/pam_hermes-agent.so") #o644)
           #t))))
    (native-inputs (list binutils tar xz))
    (home-page "https://github.com/ralt/hermes")
    (synopsis "Authenticate on Linux by plugging your USB stick")
    (description
     "Hermes is a PAM module that allows you to authenticate on Linux by simply
plugging a USB stick. It uses a challenge-response mechanism to verify that
the correct USB stick is inserted.")
    (license expat)))

hermes-agent
