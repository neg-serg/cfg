(define-module (custom packages mpdas)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages curl)
  #:use-module (gnu packages mpd))

(define-public mpdas
  (package
    (name "mpdas")
    (version "0.4.5")
    (source (origin
              (method url-fetch)
              (uri "https://github.com/hrkfdn/mpdas/archive/refs/tags/0.4.5.tar.gz")
              (sha256 (base32 "1jm9x1j48c047gg8gfn7xxs3bdscsxic1qb9lq8wsxkyi5xks469"))))
    (build-system gnu-build-system)
    (inputs (list curl libmpdclient))
    (native-inputs (list pkg-config))
    (arguments
     '(#:tests? #f
       #:make-flags (list (string-append "PREFIX=" %output)
                          "CC=gcc")
       #:phases (modify-phases %standard-phases
                  (replace 'configure
                    (lambda _
                      (substitute* "Makefile"
                        (("\\$\\(PREFIX\\)/man")
                         (string-append %output "/share/man"))
                        (("LIBS.*=.*")
                         "LIBS = -lmpdclient -lcurl"))
                      #t)))))
    (home-page "https://github.com/hrkfdn/mpdas")
    (synopsis "MPD AudioScrobbler for Last.fm")
    (description "AudioScrobbler client for MPD that submits tracks to Last.fm.")
    (license bsd-3)))

mpdas
