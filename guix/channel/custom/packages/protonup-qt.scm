(define-module (custom packages protonup-qt)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses)
  #:use-module (gnu packages elf))

(define-public protonup-qt
  (package
    (name "protonup-qt")
    (version "2.15.0")
    (source (origin
              (method url-fetch)
              (uri "https://github.com/DavidoTek/ProtonUp-Qt/releases/download/v2.15.0/ProtonUp-Qt-2.15.0-x86_64.AppImage")
              (sha256 (base32 "1lnib72jnfxq13qy8jcs2mwzmrpkfpchdxnxplgyw2r6a4xf0fhp"))))
    (build-system gnu-build-system)
    (native-inputs (list patchelf))
    (arguments
     `(#:tests? #f #:strip-binaries? #f #:validate-runpath? #f
       #:phases (modify-phases %standard-phases
         (delete 'bootstrap) (delete 'configure) (delete 'check)
         (delete 'build) (delete 'patch-usr-bin-file)
         (delete 'patch-source-shebangs) (delete 'patch-generated-file-shebangs)
         (delete 'make-dynamic-linker-cache)
         (delete 'patch-dot-desktop-files)
         (delete 'validate-documentation-location)
         (delete 'install-license-files)
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (let* ((out    (assoc-ref outputs "out"))
                    (bdir   (string-append out "/bin"))
                    (bin    "ProtonUp-Qt-2.15.0-x86_64.AppImage")
                    (glibc  (assoc-ref %build-inputs "libc"))
                    (interp (string-append glibc "/lib/ld-linux-x86-64.so.2"))
                    (pe     (string-append (assoc-ref %build-inputs "patchelf")
                                           "/bin/patchelf")))
               (mkdir-p bdir)
               (install-file bin bdir)
               (chmod (string-append bdir "/" bin) #o555)
               (false-if-exception
                (invoke pe "--set-interpreter" interp
                        (string-append bdir "/" bin)))
               #t))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://davidotek.github.io/protonup-qt")
    (synopsis "GUI for installing and updating Proton-GE and other Wine tools")
    (description "ProtonUp-Qt is a graphical tool to install and manage GE-Proton, Luxtorpeda, Boxtron, SteamTinkerLaunch and more for Steam, Lutris, and Heroic Games Launcher.")
    (license gpl3+)))

protonup-qt
