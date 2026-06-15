(define-module (custom packages satty)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix build-system trivial)
  #:use-module (guix licenses))

(define-public satty
  (package
    (name "satty")
    (version "0.21.1")
    (source (local-file "satty-built" #:recursive? #f))
    (build-system trivial-build-system)
    (arguments
     '(#:modules ((guix build utils))
       #:builder
       (begin
         (use-modules (guix build utils))
         (let* ((source (assoc-ref %build-inputs "source"))
                (out    (assoc-ref %outputs "out"))
                (bin    (string-append out "/bin")))
           (mkdir-p bin)
           (copy-file source (string-append bin "/satty"))
           (chmod (string-append bin "/satty") #o555)))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/Satty-org/Satty")
    (synopsis "Screenshot annotation tool inspired by Swappy and Flameshot")
    (description "Satty is a modern screenshot annotation tool for Wayland
compositors.  It provides on-screen drawing, text, arrows, and shape tools
for annotating screenshots after capture.")
    (license gpl3+)))

satty
