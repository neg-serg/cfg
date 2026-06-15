(define-module (custom packages uwsm)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module (guix build-system meson)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages freedesktop)
  #:use-module (gnu packages gnome)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages man)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages python)
  #:use-module (gnu packages python-xyz)
  #:use-module (gnu packages slang))

(define-public uwsm
  (package
    (name "uwsm")
    (version "0.26.5")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/Vladimir-csp/uwsm")
             (commit (string-append "v" version))))
       (file-name (git-file-name name version))
       (sha256 (base32 "01gdm5x8gkpigmwl6lgpa8i3w69zb8x6528si1x7c98m3j1kakcj"))))
    (build-system meson-build-system)
    (native-inputs (list pkg-config scdoc))
    (inputs (list bash-minimal
                  util-linux
                  newt
                  libnotify
                  python
                  python-dbus
                  python-pyxdg))
    (arguments
     (list
      #:tests? #f
      #:configure-flags
      ''("-Dcanonicalize-bins=enabled"
         "-Duuctl=enabled"
         "-Dfumon=enabled"
         "-Duwsm-app=enabled"
         "-Dman-pages=enabled")
      #:phases
      `(modify-phases %standard-phases
         (add-after 'install 'wrap-binaries
           (lambda* (#:key inputs outputs #:allow-other-keys)
             (let* ((out   (assoc-ref outputs "out"))
                    (bin   (string-append out "/bin"))
                    (dbus  (assoc-ref inputs "python-dbus"))
                    (xlib  (assoc-ref inputs "python-pyxdg"))
                    (pyver (let ((lib (car (find-files (string-append dbus "/lib")
                                                       "^python3\\."
                                                       #:directories? #t))))
                             (substring (basename lib) 6)))
                    (dbus-site (string-append dbus "/lib/python" pyver "/site-packages"))
                    (xdg-site  (string-append xlib "/lib/python" pyver "/site-packages"))
                    (path-deps (map (lambda (d)
                                      (string-append (assoc-ref inputs d) "/bin"))
                                    '("bash-minimal" "util-linux" "newt" "libnotify"))))
               (for-each
                (lambda (prog)
                  (let ((f (string-append bin "/" prog)))
                    (when (file-exists? f)
                      (wrap-program f
                        `("PATH" ":" prefix ,path-deps)
                        `("GUIX_PYTHONPATH" ":" prefix (,dbus-site ,xdg-site))))))
                '("uwsm" "uuctl" "fumon" "uwsm-app"))))))))
    (home-page "https://github.com/Vladimir-csp/uwsm")
    (synopsis "Universal Wayland Session Manager")
    (description "UWSM provides a set of systemd units and helpers to set up
the environment and manage standalone Wayland compositor sessions.  It manages
XDG autostart, application launching, environment setup/cleanup, and clean
session shutdown.  Includes optional tools: uuctl for managing user units via
dmenu, fumon for failed unit notifications, and uwsm-app for fast application
launching.")
    (license license:expat)))

uwsm
