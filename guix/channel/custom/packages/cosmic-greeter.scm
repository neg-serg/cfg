;;; cosmic-greeter --- COSMIC login screen / greeter (System76/Pop!_OS)
;;;
;;; Build: guix build -L /home/neg/src/cfg/guix/channel cosmic-greeter
;;;
;;; The source must be a pre-vendored tarball.  To create it:
;;;   1. Run: ./scripts/vendor-cosmic-deps.sh cosmic-greeter epoch-1.0.16
;;;   2. Copy the resulting tarball to this directory
;;;   3. Update the (source ...) field below with the actual SHA256
;;;
;;; This package depends on cosmic-comp at runtime.  Build-time Rust
;;; dependencies are all vendored into the source tarball.

(define-module (custom packages cosmic-greeter)
  #:use-module (guix build-system cargo)
  #:use-module (guix gexp)
  #:use-module (guix licenses)
  #:use-module (guix packages)
  #:use-module (custom packages cosmic-comp)
  #:use-module (gnu packages admin)
  #:use-module (gnu packages freedesktop)
  #:use-module (gnu packages gl)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages xdisorg)
  #:use-module (gnu packages wm))

(define-public cosmic-greeter
  (package
    (name "cosmic-greeter")
    (version "0.1.0")
    (source (local-file "cosmic-greeter-epoch-1.0.16-vendored.tar.gz"))
    (build-system cargo-build-system)
    (native-inputs (list pkg-config))
    (inputs (list cosmic-comp
                  greetd
                  libdisplay-info
                  libinput
                  libseat
                  libxkbcommon
                  linux-pam
                  mesa
                  pixman
                  eudev
                  wayland
                  wayland-protocols))
    (arguments
     '(#:tests? #f
       #:skip-build? #f
       #:install-source? #f
       #:phases (modify-phases %standard-phases
                  (add-after 'unpack 'remove-patch-section
                    (lambda _
                      (invoke "sed" "-i"
                              "/^\\[patch\\.crates-io\\]/,/^\\[/{/^\\[/!d}"
                              "../Cargo.toml"
                              "../cosmic-greeter-config/Cargo.toml")
                      #t))
                  (add-after 'configure 'use-vendored-sources
                    (lambda _
                      (delete-file ".cargo/config")
                      #t))
                  (replace 'install
                    (lambda* (#:key outputs #:allow-other-keys)
                      (let ((out (assoc-ref outputs "out")))
                        (chdir "..")
                        (mkdir-p (string-append out "/bin"))
                        (copy-file "target/release/cosmic-greeter"
                                   (string-append out "/bin/cosmic-greeter"))
                        #t))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/pop-os/cosmic-greeter")
    (synopsis "COSMIC login screen (greeter)")
    (description "COSMIC Greeter is the login screen for the COSMIC
desktop environment.  It communicates with greetd to provide user
authentication, session selection, and accessibility features on the
login screen.")
    (license gpl3)))

cosmic-greeter
