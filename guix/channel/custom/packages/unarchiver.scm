(define-module (custom packages unarchiver)
  #:use-module (guix packages)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module (guix build-system gnu)
  #:use-module (gnu packages elf)
  #:use-module (gnu packages base)
  #:use-module (gnu packages compression))

(define-public unarchiver
  (package
    (name "unarchiver")
    (version "1.10.1")
    (source
      (origin
        (method url-fetch)
        (uri "http://archive.ubuntu.com/ubuntu/pool/universe/u/unar/unar_1.10.7+ds1+really1.10.1-3build1_amd64.deb")
        (sha256
          (base32
            "0bbr6zv5jhzjb8zclj8awnxd088l2cff2d3lsll7kv3qm9kqdldh"))))
    (build-system gnu-build-system)
    (native-inputs (list patchelf tar zstd))
    (arguments
     '(#:tests? #f
       #:strip-binaries? #f
       #:validate-runpath? #f
       #:phases (modify-phases %standard-phases
         (replace 'unpack
           (lambda* (#:key source #:allow-other-keys)
             (let ((ar (which "ar")))
               (invoke ar "x" source)
               (invoke "tar" "--zstd" "-xf" "data.tar.zst")
               #t)))
         (delete 'bootstrap)
         (delete 'configure)
         (delete 'check)
         (delete 'build)
         (delete 'patch-usr-bin-file)
         (delete 'patch-source-shebangs)
         (delete 'patch-generated-file-shebangs)
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (let* ((out    (assoc-ref outputs "out"))
                    (bin    (string-append out "/bin"))
                    (glibc  (assoc-ref %build-inputs "libc"))
                    (interp (string-append glibc "/lib/ld-linux-x86-64.so.2"))
                    (pe     (string-append (assoc-ref %build-inputs "patchelf")
                                           "/bin/patchelf")))
               (mkdir-p bin)
               (for-each
                (lambda (f)
                  (copy-file f (string-append bin "/" (basename f)))
                  (invoke pe "--set-interpreter" interp
                          (string-append bin "/" (basename f)))
                  (chmod (string-append bin "/" (basename f)) #o555))
                '("usr/bin/unar" "usr/bin/lsar"))
               #t))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://theunarchiver.com/command-line")
    (synopsis "Command-line unarchiving tools (unar and lsar)")
    (description "The Unarchiver is an archive unpacker supporting many formats:
Zip, RAR, 7z, tar, gzip, bzip2, LZMA, XZ, CAB, MSI, NSIS, and more.
This package extracts pre-built binaries from the Ubuntu archive.
NOTE: Runtime requires libgnustep-base, libicuuc, and other Ubuntu system
libraries.  Compiling from source requires GNUstep (not yet in Guix).")
    (license license:lgpl2.1+)))

unarchiver
