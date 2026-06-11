(define-module (custom packages themix)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses)
  #:use-module (gnu packages glib)
  #:use-module (gnu packages gtk)
  #:use-module (gnu packages gnome)
  #:use-module (gnu packages image))

;; themix-theme-oomox — GTK2/GTK3 theme generator plugin
;; Source: shell scripts + SCSS templates, no compilation needed
(define-public themix-theme-oomox
  (package
    (name "themix-theme-oomox")
    (version "1.15.1")
    (source (origin
              (method git-fetch)
              (uri (git-reference
                    (url "https://github.com/themix-project/oomox-gtk-theme")
                    (commit "0f134c33")))
              (file-name (git-file-name name version))
               (sha256 (base32 "1xqkcfxzvmzfv6d2qlsj9qmd8k5grb8q20znpjbpk3x8m2yy40fc"))))
    (build-system gnu-build-system)
    (inputs (list gtk+ glib gdk-pixbuf librsvg sassc))
    (arguments
     '(#:tests? #f
       #:phases (modify-phases %standard-phases
         (delete 'bootstrap)
         (delete 'configure)
         (delete 'check)
         (delete 'build)
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (let* ((out    (assoc-ref outputs "out"))
                    (plugin (string-append out "/opt/oomox/plugins/theme_oomox")))
               (mkdir-p plugin)
               (copy-recursively "." plugin)
               ;; Create oomox-cli wrapper
               (let ((bin (string-append out "/bin")))
                 (mkdir-p bin)
                 (with-output-to-file (string-append bin "/oomox-cli")
                   (lambda ()
                     (format #t "#!/bin/sh~%")
                     (format #t "cd ~a && exec ./change_color.sh \"$@\"~%" plugin)))
                 (chmod (string-append bin "/oomox-cli") #o555))
               #t))))))
    (home-page "https://github.com/themix-project/oomox-gtk-theme")
    (synopsis "Oomox GTK theme generator plugin for Themix")
    (description "Generates GTK2/GTK3 themes from color palettes via change_color.sh.
Provides oomox-cli wrapper for command-line theme generation.")
    (license gpl3+)))
