(define-module (custom packages android-tools)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages compression))

(define-public android-tools
  (package
    (name "android-tools")
    (version "35.0.2")
    (source (origin
              (method url-fetch)
              (uri "https://dl.google.com/android/repository/platform-tools-latest-linux.zip")
              (sha256 (base32 "01sshvrd9a088wkvrlmrx3pjy41igcisy6bjk1asapr8mdbf32hr"))))
    (build-system gnu-build-system)
    (native-inputs (list unzip))
    (arguments
     '(#:tests? #f #:strip-binaries? #f #:validate-runpath? #f
       #:phases (modify-phases %standard-phases
                  (replace 'unpack
                    (lambda* (#:key source #:allow-other-keys)
                      (invoke "unzip" source)
                      #t))
                  (delete 'bootstrap) (delete 'configure)
                  (delete 'check) (delete 'build)
                  (delete 'patch-usr-bin-file)
                  (delete 'patch-source-shebangs)
                  (delete 'patch-generated-file-shebangs)
                  (replace 'install
                    (lambda* (#:key outputs #:allow-other-keys)
                      (let* ((out (assoc-ref outputs "out"))
                             (bin (string-append out "/bin")))
                        (mkdir-p bin)
                        (for-each (lambda (f)
                                    (copy-file f (string-append bin "/" (basename f)))
                                    (chmod (string-append bin "/" (basename f)) #o555))
                                  (find-files "platform-tools" "^(adb|fastboot|sqlite3|make_f2fs|mke2fs|etc1tool)$"))
                        #t))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://developer.android.com/studio/releases/platform-tools")
    (synopsis "Android SDK Platform Tools")
    (description "adb, fastboot, and other Android platform tools from Google.")
    (license license:asl2.0)))

android-tools
