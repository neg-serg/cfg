(define-module (custom packages haskell-tidal)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module (guix download)
  #:use-module (guix build-system haskell)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages haskell-xyz))

;; Tidal is a Haskell library for live coding algorithmic patterns.

(define tidal-source
  (origin
    (method git-fetch)
    (uri (git-reference
          (url "https://codeberg.org/uzu/tidal")
          (commit "v1.10.0")))
    (file-name (git-file-name "tidal" "1.10.0"))
    (sha256 (base32 "0sy9kc0rchj5ilkg3sz5f94p4bslymq7rq1a17fgn6zynl3b3f7g"))))

(define-public haskell-hosc
  (package
    (name "ghc-hosc")
    (version "0.21.1")
    (source (origin
              (method url-fetch)
              (uri (hackage-uri "hosc" version))
              (sha256 (base32 "1a01vp7d29503wa7sq0zy2az6zpyapjlmjszv50g2ykgb6as919v"))))
    (build-system haskell-build-system)
    (home-page "http://rohandrape.net/t/hosc")
    (synopsis "Haskell Open Sound Control")
    (description "Haskell library implementing the Open Sound Control protocol.")
    (license license:gpl3)))

(define-public haskell-tidal-core
  (package
    (name "ghc-tidal-core")
    (version "1.10.0")
    (source tidal-source)
    (build-system haskell-build-system)
    (inputs (list ghc-clock ghc-colour haskell-hosc ghc-network ghc-primitive ghc-random))
    (arguments
     `(#:phases (modify-phases %standard-phases
                  (add-before 'configure 'chdir-tidal-core
                    (lambda _
                      (chdir "tidal-core")
                      #t)))))
    (home-page "https://tidalcycles.org/")
    (synopsis "Core types and utilities for Tidal pattern language")
    (description "Core types and utilities shared across Tidal sub-packages.")
    (license license:gpl3+)))

(define-public haskell-tidal-link
  (package
    (name "ghc-tidal-link")
    (version "1.10.0")
    (source tidal-source)
    (build-system haskell-build-system)
    (inputs (list haskell-tidal-core ghc-network))
    (arguments
     `(#:phases (modify-phases %standard-phases
                  (add-before 'configure 'chdir-tidal-link
                    (lambda _
                      (chdir "tidal-link")
                      #t)))))
    (home-page "https://tidalcycles.org/")
    (synopsis "Network link types for Tidal pattern language")
    (description "Network link definitions used by Tidal.")
    (license license:gpl3+)))

(define-public haskell-tidal
  (package
    (name "haskell-tidal")
    (version "1.10.0")
    (source tidal-source)
    (build-system haskell-build-system)
    (inputs (list ghc-clock ghc-colour haskell-hosc ghc-network ghc-primitive ghc-random
                  haskell-tidal-core haskell-tidal-link))
    (arguments '(#:tests? #f))
    (home-page "https://tidalcycles.org/")
    (synopsis "Pattern language for live coding algorithmic music")
    (description "Tidal (Uzu) is a Haskell library for live coding algorithmic
patterns.  It enables real-time musical pattern manipulation and is typically
used with SuperDirt/SuperCollider for sound synthesis.  This package provides
the core library modules for import in GHCi or as a dependency.")
    (license license:gpl3+)))

haskell-tidal
