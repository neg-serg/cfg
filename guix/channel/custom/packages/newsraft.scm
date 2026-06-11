(define-module (custom packages newsraft)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses)
  #:use-module (gnu packages curl)
  #:use-module (gnu packages sqlite)
  #:use-module (gnu packages xml))

(define-public newsraft
  (package
    (name "newsraft")
    (version "0.36")
    (source (origin
              (method git-fetch)
              (uri (git-reference
                    (url "https://github.com/newsraft/newsraft")
                    (commit (string-append "newsraft-" version))))
              (file-name (git-file-name name version))
              (sha256 (base32 "2uni5y2m6ezxlvkgughlzhnvolvkugyrr3hjjjbfjiwsfp5r375a"))))
    (build-system gnu-build-system)
    (inputs (list curl expat sqlite gumbo-parser))
    (arguments
     '(#:tests? #f
       #:make-flags (list (string-append "CC=" ,(cc-for-target))
                          (string-append "PREFIX=" (assoc-ref %outputs "out")))
       #:phases (modify-phases %standard-phases
         (delete 'configure)
         (delete 'check))))
    (home-page "https://codeberg.org/newsraft/newsraft")
    (synopsis "Feed reader with terminal UI")
    (description "Newsraft is a feed reader with a text-based user interface.
It supports RSS, Atom, and other feed formats with parallel downloads,
section-based grouping, and SQL filtering.")
    (license isc)))

newsraft
