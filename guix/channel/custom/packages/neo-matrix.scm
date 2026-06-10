(define-module (custom packages neo-matrix)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses)
  #:use-module (gnu packages autotools)
  #:use-module (gnu packages ncurses))

(define-public neo-matrix
  (package
    (name "neo-matrix")
    (version "0.6.1")
    (source (origin
              (method git-fetch)
              (uri (git-reference
                    (url "https://github.com/st3w/neo")
                    (commit (string-append "v" version))))
              (file-name (git-file-name name version))
              (sha256
               (base32 "1dmhhscb8jfc4d6a3jcvb1hgcpi5pw878zznmrj810bzmv91xivd"))))
    (build-system gnu-build-system)
    (native-inputs (list autoconf automake libtool))
    (inputs (list ncurses))
    (arguments
     '(#:tests? #f))
    (home-page "https://github.com/st3w/neo")
    (synopsis "Simulate the digital rain from @dfn{The Matrix}")
    (description
     "Neo recreates the digital rain effect from @dfn{The Matrix}.
Streams of random characters will endlessly scroll down your terminal
screen.  Features include Unicode support, 16/256/32-bit color, automatic
detection of terminal capabilities, customizable colors and characters,
and support for terminal resizing.")
    (license gpl3)))

neo-matrix
