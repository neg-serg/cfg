(define-module (custom packages roomeqwizard)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages java))

(define-public roomeqwizard
  (package
    (name "roomeqwizard")
    (version "5.31.3")
    (source
     (origin
       (method url-fetch)
       (uri (string-append "https://www.roomeqwizard.com/installers/"
                           "REW_linux_no_jre_5_31_3.sh"))
       (sha256
        (base32 "09nlzgzqac5n04qm6vlwa7l65ld8xsk3502jb6a9s112b8ls98d9"))))
    (build-system gnu-build-system)
    (native-inputs (list bash-minimal icedtea-8))
    (inputs (list bash-minimal icedtea-8))
    (arguments
     `(#:tests? #f
       #:strip-binaries? #f
       #:phases (modify-phases %standard-phases
         (delete 'bootstrap) (delete 'configure) (delete 'check)
         (delete 'build) (delete 'patch-usr-bin-file)
         (delete 'patch-source-shebangs) (delete 'patch-generated-file-shebangs)
         (replace 'unpack
           (lambda* (#:key source #:allow-other-keys)
             (copy-file source "installer.sh")
             (chmod "installer.sh" #o755)
             #t))
         (replace 'install
           (lambda* (#:key outputs inputs #:allow-other-keys)
             (let* ((out       (assoc-ref outputs "out"))
                    (share     (string-append out "/share/roomeqwizard"))
                    (bin       (string-append out "/bin"))
                    (java-home (assoc-ref inputs "icedtea"))
                    (bash      (search-input-file inputs "bin/bash")))
               (setenv "INSTALL4J_JAVA_HOME_OVERRIDE" java-home)
               (mkdir-p share)
               (mkdir-p bin)
               (invoke "sh" "installer.sh" "-q" "-dir" share
                       "-J-Djava.util.prefs.userRoot=/tmp/rew-prefs"
                       "-J-Djava.util.prefs.systemRoot=/tmp/rew-sprefs")
               ;; Apply waterfall crash workaround (opengl=True)
               (substitute* (string-append share "/roomeqwizard.vmoptions")
                 (("-Dsun.java2d.opengl=False")
                  "-Dsun.java2d.opengl=True"))
               ;; Remove installer conflict with uninstall dir
               (delete-file-recursively
                (string-append share "/uninstall"))
               ;; Create wrapper script that ensures Java is on PATH
               (with-output-to-file (string-append bin "/roomeqwizard")
                 (lambda ()
                   (format #t "#!~a~%" bash)
                   (format #t "export PATH=\"~a/bin:$PATH\"~%" java-home)
                   (format #t "exec \"~a/roomeqwizard\" \"$@\"~%" share)))
               (chmod (string-append bin "/roomeqwizard") #o755)
               #t))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://www.roomeqwizard.com")
    (synopsis "Room acoustics measurement and analysis software")
    (description
     "REW (Room EQ Wizard) is professional-grade room acoustics measurement
and analysis software.  It supports measuring rooms, speakers, subwoofers and
audio devices, impulse response measurement, realtime analysis, EQ
configuration, and spectrogram visualization.")
    (license (license:non-copyleft "https://www.roomeqwizard.com/"))))

roomeqwizard
