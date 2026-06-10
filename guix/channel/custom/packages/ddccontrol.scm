(define-module (custom packages ddccontrol)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses)
  #:use-module (gnu packages autotools)
  #:use-module (gnu packages gettext)
  #:use-module (gnu packages glib)
  #:use-module (gnu packages gtk)
  #:use-module (gnu packages pciutils)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages xml))

(define-public ddccontrol
  (package
    (name "ddccontrol")
    (version "2.0.0")
    (source (origin
              (method url-fetch)
              (uri "https://github.com/ddccontrol/ddccontrol/archive/2.0.0.tar.gz")
              (sha256 (base32 "1bg6drl2rfkyn8466mn1z85i906xwzy8bimw8s90a1m6az7jv1qn"))))
    (build-system gnu-build-system)
    (native-inputs (list (list glib "bin") autoconf automake gettext-minimal intltool libtool pkg-config))
    (inputs (list gtk+ libxml2 pciutils))
    (arguments
     '(#:tests? #f
       #:phases (modify-phases %standard-phases
                  (add-after 'configure 'fix-icon-cache
                    (lambda _
                      (substitute* (find-files "." "Makefile" #:directories? #f)
                        (("gtk-update-icon-cache") "true")))))))
    (home-page "https://github.com/ddccontrol/ddccontrol")
    (synopsis "DDC/CI monitor control")
    (description "Control monitor settings via DDC/CI.")
    (license gpl2+)))

ddccontrol
