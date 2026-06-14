(define-module (custom packages gamescope)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module (guix build-system meson)
  #:use-module (guix licenses)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages gl)
  #:use-module (gnu packages xorg)
  #:use-module (gnu packages vulkan)
  #:use-module (gnu packages image)
  #:use-module (gnu packages wayland))

(define-public gamescope
  (package
    (name "gamescope")
    (version "3.17.4")
    (source (origin
              (method git-fetch)
              (uri (git-reference
                    (url "https://github.com/ValveSoftware/gamescope")
                    (commit version)))
              (file-name (git-file-name name version))
              (sha256 (base32 "0000000000000000000000000000000000000000000000000000"))))
    (build-system meson-build-system)
    (native-inputs (list pkg-config))
    (inputs (list libx11
                  libxcomposite
                  libxdamage
                  libxext
                  libxfixes
                  libxrender
                  libxres
                  libxxf86vm
                  libxtst
                  libdrm
                  mesa
                  vulkan-headers
                  vulkan-loader
                  wayland
                  wayland-protocols
                  libdecor
                  libinput
                  libxkbcommon
                  libcap
                  pipewire
                  sdl2
                  stb
                  pixman
                  libavif))
    (arguments
     '(#:tests? #f
       #:configure-flags '("-Dpipewire=enabled")))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/ValveSoftware/gamescope")
    (synopsis "Micro-compositor for games on Wayland")
    (description "Gamescope is a micro-compositor from Valve that provides an
isolated compositor for gaming on Wayland.  It supports features like integer
scaling, HDR, frame rate limiting, and AMD FSR/NIS upscaling.")
    (license bsd-2)))

gamescope
