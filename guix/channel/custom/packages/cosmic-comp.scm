;;; cosmic-comp --- COSMIC desktop compositor (System76/Pop!_OS)
;;;
;;; Build: guix build -L /home/neg/src/cfg/guix/channel cosmic-comp
;;;
;;; The source is a pre-vendored tarball created by:
;;;   ./scripts/vendor-cosmic-deps.sh cosmic-comp epoch-1.0.16
;;; which vendors all Rust dependencies (crates.io + git) for offline build.

(define-module (custom packages cosmic-comp)
  #:use-module (guix build-system cargo)
  #:use-module (guix gexp)
  #:use-module (guix licenses)
  #:use-module (guix packages)
  #:use-module (gnu packages admin)
  #:use-module (gnu packages freedesktop)
  #:use-module (gnu packages gl)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages xdisorg)
  #:use-module (gnu packages wm))

(define-public cosmic-comp
  (package
    (name "cosmic-comp")
    (version "1.0.0")
    (source (local-file "cosmic-comp-epoch-1.0.16-vendored.tar.gz"))
    (build-system cargo-build-system)
    (native-inputs (list pkg-config))
    (inputs (list libdisplay-info
                  libinput
                  libseat
                  libxkbcommon
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
                              "../cosmic-comp-config/Cargo.toml")
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
                        (copy-file "target/release/cosmic-comp"
                                   (string-append out "/bin/cosmic-comp"))
                        #t))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/pop-os/cosmic-comp")
    (synopsis "COSMIC desktop compositor")
    (description "COSMIC Comp is the Wayland compositor for the COSMIC
desktop environment by System76.  It is built on Smithay and provides
window management, rendering, input handling, and display configuration
for the COSMIC desktop.")
    (license gpl3)))

cosmic-comp
