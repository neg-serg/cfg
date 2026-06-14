(define-module (custom packages unflac)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses)
  #:use-module (gnu packages golang))

(define-public unflac
  (package
    (name "unflac")
    (version "1.4")
    (source (origin
              (method git-fetch)
              (uri (git-reference
                    (url "https://github.com/nilzeronull/unflac")
                    (commit "0ed8af0cfc4a0a1487b9b556d4923dc2fd276a5d")))
              (file-name (git-file-name name version))
              (sha256 (base32 "1a36gag3zba11rwrzpk6pc5yavwbmkifbdk5j3zbkm32y93iraij"))))
    (build-system gnu-build-system)
    (native-inputs (list go))
    (arguments
     '(#:tests? #f
       #:phases (modify-phases %standard-phases
         (delete 'bootstrap)
         (delete 'configure)
         (delete 'check)
           (replace 'build
             (lambda _
               (setenv "HOME" "/tmp")
               (setenv "GOPROXY" "off")
               (setenv "GOFLAGS" "-mod=mod")
               (invoke "go" "build" "-o" "unflac" ".")
               #t))
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (let ((bin (string-append (assoc-ref outputs "out") "/bin")))
               (mkdir-p bin)
               (install-file "unflac" bin)
               #t))))))
    (home-page "https://git.sr.ht/~ft/unflac")
    (synopsis "Fast frame-accurate audio image + cue sheet splitter")
    (description "unflac splits audio images using cue sheets, written in Go.")
    (license bsd-3)))

unflac
