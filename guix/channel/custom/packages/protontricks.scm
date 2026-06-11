(define-module (custom packages protontricks)
  #:use-module (custom packages winetricks)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module (guix build-system python)
  #:use-module (guix licenses)
  #:use-module (gnu packages python)
  #:use-module (gnu packages python-build)
  #:use-module (gnu packages python-xyz)
  #:use-module ((custom packages python-ports) #:select (python-vdf)))

(define-public protontricks
  (package
    (name "protontricks")
    (version "1.14.1")
    (source (origin
              (method git-fetch)
              (uri (git-reference
                    (url "https://github.com/Matoking/protontricks")
                    (commit version)))
              (file-name (git-file-name name version))
              (sha256
               (base32
                "0qjl3mfr0gqqd16vm078c2knw9l76aznzb3kjyl4j5a6436njc55"))))
    (build-system python-build-system)
    (native-inputs
     (list python-setuptools-scm))
    (arguments
     '(#:tests? #f
       #:phases (modify-phases %standard-phases
         (add-before 'build 'set-version
           (lambda _
             (setenv "SETUPTOOLS_SCM_PRETEND_VERSION" "1.14.1"))))))
    (inputs
     (list python-pillow python-vdf winetricks))
    (home-page "https://github.com/Matoking/protontricks")
    (synopsis "Wrapper for running Winetricks commands for Proton games")
    (description "Protontricks is a wrapper script that allows you to
run Winetricks commands for Steam Play/Proton games among other
common Wine features.  It uses Winetricks for performing workarounds
and applies them to Proton game prefixes.")
    (license gpl3+)))

protontricks
