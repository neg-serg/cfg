(define-module (custom packages ghostty)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages zig))

(define-public ghostty
  (package
    (name "ghostty")
    (version "1.1.3")
    (source (origin
              (method git-fetch)
              (uri (git-reference
                    (url "https://github.com/ghostty-org/ghostty")
                    (commit (string-append "v" version))))
              (file-name (git-file-name name version))
              (sha256 (base32 "0glwj88s8jj8vrlc42fzwj4v8yzm01szvnl4mg51qaw5wddk4yk0"))))
    (build-system gnu-build-system)
    (native-inputs (list pkg-config zig))
    (arguments
     '(#:tests? #f
       #:phases (modify-phases %standard-phases
                  (delete 'configure)
                  (delete 'check)
                  (replace 'build
                    (lambda _
                      (invoke "zig" "build" "-Doptimize=ReleaseSafe")))
                  (replace 'install
                    (lambda* (#:key outputs #:allow-other-keys)
                      (let* ((out (assoc-ref outputs "out"))
                             (bin (string-append out "/bin")))
                        (mkdir-p bin)
                        (install-file "zig-out/bin/ghostty" bin)))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://ghostty.org")
    (synopsis "Fast, feature-rich, cross-platform terminal emulator")
    (description "Ghostty is a terminal emulator that differentiates itself by
being fast, feature-rich, and native.  It uses platform-native technologies
(GTK on Linux, SwiftUI on macOS) for its GUI.")
    (license expat)))

ghostty
