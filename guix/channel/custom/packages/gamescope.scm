(define-module (custom packages gamescope)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module (guix build-system meson)
  #:use-module (guix licenses)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages gl)
  #:use-module (gnu packages maths)
  #:use-module (gnu packages xorg)
  #:use-module (gnu packages xdisorg)
  #:use-module (gnu packages vulkan)
  #:use-module (gnu packages image)
  #:use-module (gnu packages freedesktop)
  #:use-module (gnu packages stb)
  #:use-module (gnu packages sdl)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages pciutils)
  #:use-module (gnu packages admin)
  #:use-module (gnu packages ghostscript)
  #:use-module (gnu packages wm)
  #:use-module (gnu packages lua)
  #:use-module (gnu packages version-control))

(define-public gamescope
  (package
    (name "gamescope")
    (version "3.16.24")
    (source (origin
              (method git-fetch)
              (uri (git-reference
                    (url "https://github.com/ValveSoftware/gamescope")
                    (commit version)
                    (recursive? #t)))
              (file-name (git-file-name name version))
              (sha256 (base32 "1w8b1wyqps5nf55wih3ypf8pnp45yn61q2dmj14y2a060m0c927v"))))
    (build-system meson-build-system)
    (native-inputs (list pkg-config git-minimal))
    (inputs (list libx11
                  libxcomposite
                  libxdamage
                  libxext
                  libxfixes
                  libxrender
                  libxres
                  libxxf86vm
                  libxtst
                  libxcursor
                  libxmu
                  libxi
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
                  libavif
                  glm
                  hwdata
                  eudev
                  glslang
                  libseat
                  lcms
                  xorg-server-xwayland
                  xcb-util-wm
                  libdisplay-info
                  libliftoff
                  luajit))
    (arguments
     `(#:tests? #f
       #:configure-flags '("-Dpipewire=enabled"
                           "-Denable_openvr_support=false"
                           "-Denable_tests=false")
       #:phases
       (modify-phases %standard-phases
         (add-after 'unpack 'populate-subprojects
           (lambda* (#:key inputs #:allow-other-keys)
             ;; Pre-populate subproject directories so meson doesn't try
             ;; to download them with git (offline build).
             (let ((glm-src (assoc-ref inputs "glm"))
                   (stb-src (assoc-ref inputs "stb"))
                   (pkgfiles "subprojects/packagefiles"))
               ;; glm: copy headers from system package
               (mkdir-p "subprojects/glm")
               (copy-recursively (string-append glm-src "/include/glm")
                                 "subprojects/glm/glm")
               (copy-file (string-append pkgfiles "/glm/meson.build")
                          "subprojects/glm/meson.build")
                ;; stb: copy system package into subproject (headers + any dirs)
                (copy-recursively stb-src "subprojects/stb")
                (copy-file (string-append pkgfiles "/stb/meson.build")
                           "subprojects/stb/meson.build")
                ;; gamescope uses deprecated stb_image_resize.h which
                ;; the Guix stb package puts under deprecated/
                ;; copy it to root so the build finds it
                (copy-file (string-append stb-src "/deprecated/stb_image_resize.h")
                           "subprojects/stb/stb_image_resize.h")
               #t))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/ValveSoftware/gamescope")
    (synopsis "Micro-compositor for games on Wayland")
    (description "Gamescope is a micro-compositor from Valve that provides an
isolated compositor for gaming on Wayland.  It supports features like integer
scaling, HDR, frame rate limiting, and AMD FSR/NIS upscaling.")
    (license bsd-2)))

gamescope
