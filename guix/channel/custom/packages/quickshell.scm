(define-module (custom packages quickshell)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix git-download)
  #:use-module (guix build-system cmake)
  #:use-module (guix licenses)
  #:use-module (gnu packages cmake)
  #:use-module (gnu packages build-tools)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages qt)
  #:use-module (gnu packages xorg)
  #:use-module (gnu packages gl)
  #:use-module (gnu packages freedesktop)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages pulseaudio)
  #:use-module (gnu packages version-control)
  #:use-module (gnu packages xdisorg)
  #:use-module (gnu packages jemalloc)
  #:use-module (gnu packages glib)
  #:use-module (gnu packages polkit)
  #:use-module (gnu packages cpp))

(define-public quickshell
  (package
    (name "quickshell")
    (version "0.3.0")
    (source (origin
              (method git-fetch)
              (uri (git-reference
                    (url "https://git.outfoxxed.me/quickshell/quickshell")
                    (commit "v0.3.0")))
              (file-name (git-file-name name version))
              (sha256 (base32 "1rmr5lh2byj1l9lpkf2ypgcbx6wgdyjn5ba9hgpnn9q6khd9akw1"))))
    (build-system cmake-build-system)
    (arguments
     `(#:tests? #f
       #:build-type "Ninja"
       #:configure-flags
         (list "-DCMAKE_BUILD_TYPE=RelWithDebInfo"
               "-DDISTRIBUTOR=Guix"
               "-DCRASH_HANDLER=OFF"
               "-DINSTALL_QML_PREFIX=lib/qt6/qml")
       #:phases
       (modify-phases %standard-phases
         (add-after 'unpack 'fix-build
           (lambda _
             (substitute* "src/CMakeLists.txt"
               (("add_subdirectory\\(crash\\).*") ""))
             (substitute* "src/dbus/CMakeLists.txt"
               (("add_subdirectory\\(dbusmenu\\)") ""))
             (substitute* "src/services/CMakeLists.txt"
               (("add_subdirectory\\(status_notifier\\).*") ""))
             #t))
         (delete 'check))))
    (native-inputs
     (list ninja pkg-config cmake-minimal git-minimal cli11))
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
           jemalloc
           glib
           polkit
           linux-pam))
    (supported-systems '("x86_64-linux"))
    (home-page "https://git.outfoxxed.me/quickshell/quickshell")
    (synopsis "Flexible toolkit for making desktop shells with QtQuick")
    (description "Quickshell is a flexible toolkit for building desktop shells
using QtQuick.")
    (license lgpl3)))

quickshell
