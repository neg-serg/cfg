(define-module (custom packages quickshell)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system cmake)
  #:use-module (guix licenses)
  #:use-module (gnu packages cmake)
  #:use-module (gnu packages ninja)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages qt)
  #:use-module (gnu packages xorg)
  #:use-module (gnu packages gl)
  #:use-module (gnu packages freedesktop)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages pulseaudio)
  #:use-module (gnu packages version-control)
  #:use-module (gnu packages man))

(define-public quickshell
  (package
    (name "quickshell")
    (version "0.3.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "https://git.outfoxxed.me/quickshell/quickshell/archive/v"
                    version ".tar.gz"))
               (sha256
                (base32 "6sbb7eeezkyexuvvhbgmsk4xe2xmythd5mtsadoketw4m7ndw3sq"))))
    (build-system cmake-build-system)
    (arguments
     `(#:tests? #f
       #:configure-flags
       (list "-GNinja"
             "-DCMAKE_BUILD_TYPE=RelWithDebInfo"
             "-DDISTRIBUTOR=Guix"
             "-DINSTALL_QML_PREFIX=lib/qt6/qml")
       #:phases
       (modify-phases %standard-phases
         ;; Skip tests — quickshell requires a running Wayland compositor
         (delete 'check))))
    (native-inputs
     (list ninja pkg-config cmake-minimal git-minimal))
    (inputs
     (list qtbase
           qtdeclarative
           qtsvg
           qtwayland
           qtshadertools
           qttools
           qtimageformats
           qtmultimedia
           wayland
           wayland-protocols
           mesa
           libdrm
           libglvnd
           libxcb
           pipewire
           jemalloc))
    (supported-systems '("x86_64-linux"))
    (home-page "https://git.outfoxxed.me/quickshell/quickshell")
    (synopsis "Flexible toolkit for making desktop shells with QtQuick")
    (description "Quickshell is a flexible toolkit for building desktop shells
using QtQuick.  It provides the runtime environment for Wayland shells like Ambxst.")
    (license lgpl3)))
