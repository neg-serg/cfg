(define-module (custom packages gist)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system ruby)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages ruby))

(define-public gist
  (package
    (name "gist")
    (version "6.0.0")
    (source (origin
              (method url-fetch)
              (uri (rubygems-uri "gist" version))
              (sha256
               (base32 "0qnd1jqd7b04871v4l73grcmi7c0pivm8nsfrqvwivm4n4b3c2hd"))))
    (build-system ruby-build-system)
    (arguments
     '(#:tests? #f
       #:phases (modify-phases %standard-phases
                  (add-after 'extract-gemspec 'relax-dependency-requirements
                    (lambda _
                      (substitute* "gist.gemspec"
                        ((".*add_dependency.*") "")))))))
    (home-page "https://github.com/defunkt/gist")
    (synopsis "Command-line tool for creating and managing GitHub Gists")
    (description "Gist is a command-line interface to GitHub Gists.
It allows you to create, list, read, update, and delete gists directly
from the terminal.")
    (license license:expat)))

gist
