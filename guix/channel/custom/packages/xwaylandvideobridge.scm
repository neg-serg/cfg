(define-module (custom packages xwaylandvideobridge)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module (guix build-system cmake)
  #:use-module (guix licenses)
  #:use-module (gnu packages cmake)
  #:use-module (gnu packages gettext)
  #:use-module (gnu packages kde-frameworks)
  #:use-module (gnu packages kde-plasma)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages qt)
  #:use-module (gnu packages xorg))

(define-public xwaylandvideobridge
  (package
    (name "xwaylandvideobridge")
    (version "0.5.0")
    (source (origin
              (method git-fetch)
              (uri (git-reference
                    (url "https://invent.kde.org/system/xwaylandvideobridge")
                    (commit (string-append "v" version))))
              (file-name (git-file-name name version))
              (sha256
               (base32
                "0xaa7k98mp8k2a9nigxg2cgby3h7z1q8yx5xnxngwq1kc9x9xmb7"))))
    (build-system cmake-build-system)
    (native-inputs (list extra-cmake-modules pkg-config gettext-minimal))
    (inputs (list kcoreaddons
                  kcrash
                  ki18n
                  kpipewire
                  kstatusnotifieritem
                  kwindowsystem
                  libxcb
                  qtbase
                  qtdeclarative
                  xcb-util))
    (arguments
     '(#:tests? #f
       #:phases
       (modify-phases %standard-phases
         (add-before 'configure 'remove-unused-xcb-event
           (lambda _
             (substitute* "CMakeLists.txt"
               (("COMPOSITE EVENT RECORD")
                "COMPOSITE RECORD")))))))
    (home-page "https://invent.kde.org/system/xwaylandvideobridge")
    (synopsis "Share Wayland windows with X11 applications")
    (description "By design, X11 applications cannot access window or screen
contents for Wayland clients.  This breaks screen sharing in tools like
Discord, MS Teams, and Skype.  XWayland Video Bridge allows you to share
specific windows with X11 applications while keeping the user in full
control.")
    (license bsd-3)
    (supported-systems '("x86_64-linux"))))

xwaylandvideobridge
