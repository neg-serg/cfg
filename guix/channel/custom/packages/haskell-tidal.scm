(define-module (custom packages haskell-tidal)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module (guix build-system haskell)
  #:use-module ((guix licenses) #:prefix license:))

;; Tidal is a Haskell library for live coding algorithmic patterns.
;; It does not produce a standalone binary -- it is loaded via GHCi
;; and used with SuperDirt/SuperCollider.  This package provides the
;; library for use as a dependency or REPL import.

(define-public haskell-tidal
  (package
    (name "haskell-tidal")
    (version "1.10.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://codeberg.org/uzu/tidal")
             (commit (string-append "v" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "0sy9kc0rchj5ilkg3sz5f94p4bslymq7rq1a17fgn6zynl3b3f7g"))))
    (build-system haskell-build-system)
    (arguments '(#:tests? #f))
    (home-page "https://tidalcycles.org/")
    (synopsis "Pattern language for live coding algorithmic music")
    (description "Tidal (Uzu) is a Haskell library for live coding algorithmic
patterns.  It enables real-time musical pattern manipulation and is typically
used with SuperDirt/SuperCollider for sound synthesis.  This package provides
the core library modules for import in GHCi or as a dependency.")
    (license license:gpl3+)))

haskell-tidal
