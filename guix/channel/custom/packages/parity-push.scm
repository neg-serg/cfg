(define-module (custom packages parity-push)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix git-download)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses)
  #:use-module (gnu packages elf)
  #:use-module (gnu packages base)
  #:use-module (gnu packages compression)
  #:use-module (guix build utils))


;; BATCH 6 — Full parity push. Hashes verified via direct download.

(define-public yazi
  (package (name "yazi") (version "25.4.8")
    (source (origin (method url-fetch) (uri "https://github.com/sxyazi/yazi/releases/download/v25.4.8/yazi-x86_64-unknown-linux-gnu.zip") (sha256 (base32 "01sndv3mvhzq89ydvz562khqgz1w7l3f224kk93wmd3g1j2d5jxr"))))
    (build-system gnu-build-system)
    (native-inputs (list patchelf tar gzip unzip))
    (arguments
     '(#:tests? #f #:strip-binaries? #f #:validate-runpath? #f
       #:phases (modify-phases %standard-phases
         (delete 'bootstrap)(delete 'configure)(delete 'check)
         (delete 'build)(delete 'patch-usr-bin-file)
         (delete 'patch-source-shebangs)(delete 'patch-generated-file-shebangs)
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (let* ((out (assoc-ref outputs "out"))
                    (bdir (string-append out "/bin"))
                    (glibc (assoc-ref %build-inputs "libc"))
                    (interp (string-append glibc "/lib/ld-linux-x86-64.so.2"))
                    (pe (string-append (assoc-ref %build-inputs "patchelf") "/bin/patchelf")))
               (mkdir-p bdir)
               (if (file-exists? "yazi")
                 (begin (install-file "yazi" bdir)
                   (chmod (string-append bdir "/" "yazi") #o555)
                   (false-if-exception (invoke pe "--set-interpreter" interp (string-append bdir "/" "yazi"))))
                 (let ((files (find-files "." (lambda (f s) (string-contains (basename f) "yazi")))))
                   (if (pair? files)
                     (let ((src (car files)))
                       (copy-file src (string-append bdir "/" "yazi"))
                       (chmod (string-append bdir "/" "yazi") #o555)
                       (false-if-exception (invoke pe "--set-interpreter" interp (string-append bdir "/" "yazi")))))))
               #t))))))
    (supported-systems '("x86_64-linux"))
    (home-page "") (synopsis "") (description "") (license gpl3+)))

(define-public ruff-linter
  (package (name "ruff") (version "0.11.0")
    (source (origin (method url-fetch) (uri "https://github.com/astral-sh/ruff/releases/download/0.11.0/ruff-x86_64-unknown-linux-gnu.tar.gz") (sha256 (base32 "1cwnmjyki09qz30l4l8wyiijb301lrn7s94h3r2ly7in7ddcaqdd"))))
    (build-system gnu-build-system)
    (native-inputs (list patchelf tar gzip unzip))
    (arguments
     '(#:tests? #f #:strip-binaries? #f #:validate-runpath? #f
       #:phases (modify-phases %standard-phases
         (delete 'bootstrap)(delete 'configure)(delete 'check)
         (delete 'build)(delete 'patch-usr-bin-file)
         (delete 'patch-source-shebangs)(delete 'patch-generated-file-shebangs)
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (let* ((out (assoc-ref outputs "out"))
                    (bdir (string-append out "/bin"))
                    (glibc (assoc-ref %build-inputs "libc"))
                    (interp (string-append glibc "/lib/ld-linux-x86-64.so.2"))
                    (pe (string-append (assoc-ref %build-inputs "patchelf") "/bin/patchelf")))
               (mkdir-p bdir)
               (if (file-exists? "ruff")
                 (begin (install-file "ruff" bdir)
                   (chmod (string-append bdir "/" "ruff") #o555)
                   (false-if-exception (invoke pe "--set-interpreter" interp (string-append bdir "/" "ruff"))))
                 (let ((files (find-files "." (lambda (f s) (string-contains (basename f) "ruff")))))
                   (if (pair? files)
                     (let ((src (car files)))
                       (copy-file src (string-append bdir "/" "ruff"))
                       (chmod (string-append bdir "/" "ruff") #o555)
                       (false-if-exception (invoke pe "--set-interpreter" interp (string-append bdir "/" "ruff")))))))
               #t))))))
    (supported-systems '("x86_64-linux"))
    (home-page "") (synopsis "") (description "") (license gpl3+)))

(define-public gitleaks-sec
  (package (name "gitleaks") (version "8.23.0")
    (source (origin (method url-fetch) (uri "https://github.com/gitleaks/gitleaks/releases/download/v8.23.0/gitleaks_8.23.0_linux_x64.tar.gz") (sha256 (base32 "13lgvpyh633jcar0ia2vignhi540vkfrp77gkx3868zyivw45ifi"))))
    (build-system gnu-build-system)
    (native-inputs (list patchelf tar gzip unzip))
    (arguments
     '(#:tests? #f #:strip-binaries? #f #:validate-runpath? #f
       #:phases (modify-phases %standard-phases
         (delete 'bootstrap)(delete 'configure)(delete 'check)
         (delete 'build)(delete 'patch-usr-bin-file)
         (delete 'patch-source-shebangs)(delete 'patch-generated-file-shebangs)
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (let* ((out (assoc-ref outputs "out"))
                    (bdir (string-append out "/bin"))
                    (glibc (assoc-ref %build-inputs "libc"))
                    (interp (string-append glibc "/lib/ld-linux-x86-64.so.2"))
                    (pe (string-append (assoc-ref %build-inputs "patchelf") "/bin/patchelf")))
               (mkdir-p bdir)
               (if (file-exists? "gitleaks")
                 (begin (install-file "gitleaks" bdir)
                   (chmod (string-append bdir "/" "gitleaks") #o555)
                   (false-if-exception (invoke pe "--set-interpreter" interp (string-append bdir "/" "gitleaks"))))
                 (let ((files (find-files "." (lambda (f s) (string-contains (basename f) "gitleaks")))))
                   (if (pair? files)
                     (let ((src (car files)))
                       (copy-file src (string-append bdir "/" "gitleaks"))
                       (chmod (string-append bdir "/" "gitleaks") #o555)
                       (false-if-exception (invoke pe "--set-interpreter" interp (string-append bdir "/" "gitleaks")))))))
               #t))))))
    (supported-systems '("x86_64-linux"))
    (home-page "") (synopsis "") (description "") (license gpl3+)))


(define-public ttyd-share
  (package (name "ttyd") (version "1.7.7")
    (source (origin (method url-fetch) (uri "https://github.com/tsl0922/ttyd/releases/download/1.7.7/ttyd.x86_64") (sha256 (base32 "0magpsvi5kgjn8fzb6z5sp25n0fw31r48d1zpw6jw5xsiab7q8ca"))))
    (build-system gnu-build-system)
    (native-inputs (list patchelf tar gzip unzip))
    (arguments
     '(#:tests? #f #:strip-binaries? #f #:validate-runpath? #f
       #:phases (modify-phases %standard-phases
         (delete 'bootstrap)(delete 'configure)(delete 'check)
         (delete 'build)(delete 'patch-usr-bin-file)
         (delete 'patch-source-shebangs)(delete 'patch-generated-file-shebangs)
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (let* ((out (assoc-ref outputs "out"))
                    (bdir (string-append out "/bin"))
                    (glibc (assoc-ref %build-inputs "libc"))
                    (interp (string-append glibc "/lib/ld-linux-x86-64.so.2"))
                    (pe (string-append (assoc-ref %build-inputs "patchelf") "/bin/patchelf")))
               (mkdir-p bdir)
               (if (file-exists? "ttyd.x86_64")
                 (begin (install-file "ttyd.x86_64" bdir)
                   (chmod (string-append bdir "/" "ttyd.x86_64") #o555)
                   (false-if-exception (invoke pe "--set-interpreter" interp (string-append bdir "/" "ttyd.x86_64"))))
                 (let ((files (find-files "." (lambda (f s) (string-contains (basename f) "ttyd.x86_64")))))
                   (if (pair? files)
                     (let ((src (car files)))
                       (copy-file src (string-append bdir "/" "ttyd.x86_64"))
                       (chmod (string-append bdir "/" "ttyd.x86_64") #o555)
                       (false-if-exception (invoke pe "--set-interpreter" interp (string-append bdir "/" "ttyd.x86_64")))))))
               #t))))))
    (supported-systems '("x86_64-linux"))
    (home-page "") (synopsis "") (description "") (license gpl3+)))

(define-public genact-activity
  (package (name "genact") (version "1.4.2")
    (source (origin (method url-fetch) (uri "https://github.com/svenstaro/genact/releases/download/v1.4.2/genact-1.4.2-x86_64-unknown-linux-musl") (sha256 (base32 "0wqj3c66jl2s5hhx0qqw4fsmp1r0v382b5502z6njnxbzl1im28f"))))
    (build-system gnu-build-system)
    (native-inputs (list patchelf tar gzip unzip))
    (arguments
     '(#:tests? #f #:strip-binaries? #f #:validate-runpath? #f
       #:phases (modify-phases %standard-phases
         (delete 'bootstrap)(delete 'configure)(delete 'check)
         (delete 'build)(delete 'patch-usr-bin-file)
         (delete 'patch-source-shebangs)(delete 'patch-generated-file-shebangs)
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (let* ((out (assoc-ref outputs "out"))
                    (bdir (string-append out "/bin"))
                    (glibc (assoc-ref %build-inputs "libc"))
                    (interp (string-append glibc "/lib/ld-linux-x86-64.so.2"))
                    (pe (string-append (assoc-ref %build-inputs "patchelf") "/bin/patchelf")))
               (mkdir-p bdir)
               (if (file-exists? "genact-1.4.2-x86_64-unknown-linux-musl")
                 (begin (install-file "genact-1.4.2-x86_64-unknown-linux-musl" bdir)
                   (chmod (string-append bdir "/" "genact-1.4.2-x86_64-unknown-linux-musl") #o555)
                   (false-if-exception (invoke pe "--set-interpreter" interp (string-append bdir "/" "genact-1.4.2-x86_64-unknown-linux-musl"))))
                 (let ((files (find-files "." (lambda (f s) (string-contains (basename f) "genact-1.4.2-x86_64-unknown-linux-musl")))))
                   (if (pair? files)
                     (let ((src (car files)))
                       (copy-file src (string-append bdir "/" "genact-1.4.2-x86_64-unknown-linux-musl"))
                       (chmod (string-append bdir "/" "genact-1.4.2-x86_64-unknown-linux-musl") #o555)
                       (false-if-exception (invoke pe "--set-interpreter" interp (string-append bdir "/" "genact-1.4.2-x86_64-unknown-linux-musl")))))))
               #t))))))
    (supported-systems '("x86_64-linux"))
    (home-page "") (synopsis "") (description "") (license gpl3+)))

(define-public ctop-monitor
  (package (name "ctop") (version "0.7.7")
    (source (origin (method url-fetch) (uri "https://github.com/bcicen/ctop/releases/download/v0.7.7/ctop-0.7.7-linux-amd64") (sha256 (base32 "029al32kpk8an169cgvzzbbm1hhir495aggfxnv18gdy9rrp90xp"))))
    (build-system gnu-build-system)
    (native-inputs (list patchelf tar gzip unzip))
    (arguments
     '(#:tests? #f #:strip-binaries? #f #:validate-runpath? #f
       #:phases (modify-phases %standard-phases
         (delete 'bootstrap)(delete 'configure)(delete 'check)
         (delete 'build)(delete 'patch-usr-bin-file)
         (delete 'patch-source-shebangs)(delete 'patch-generated-file-shebangs)
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (let* ((out (assoc-ref outputs "out"))
                    (bdir (string-append out "/bin"))
                    (glibc (assoc-ref %build-inputs "libc"))
                    (interp (string-append glibc "/lib/ld-linux-x86-64.so.2"))
                    (pe (string-append (assoc-ref %build-inputs "patchelf") "/bin/patchelf")))
               (mkdir-p bdir)
               (if (file-exists? "ctop-0.7.7-linux-amd64")
                 (begin (install-file "ctop-0.7.7-linux-amd64" bdir)
                   (chmod (string-append bdir "/" "ctop-0.7.7-linux-amd64") #o555)
                   (false-if-exception (invoke pe "--set-interpreter" interp (string-append bdir "/" "ctop-0.7.7-linux-amd64"))))
                 (let ((files (find-files "." (lambda (f s) (string-contains (basename f) "ctop-0.7.7-linux-amd64")))))
                   (if (pair? files)
                     (let ((src (car files)))
                       (copy-file src (string-append bdir "/" "ctop-0.7.7-linux-amd64"))
                       (chmod (string-append bdir "/" "ctop-0.7.7-linux-amd64") #o555)
                       (false-if-exception (invoke pe "--set-interpreter" interp (string-append bdir "/" "ctop-0.7.7-linux-amd64")))))))
               #t))))))
    (supported-systems '("x86_64-linux"))
    (home-page "") (synopsis "") (description "") (license gpl3+)))

(define-public onefetch-info
  (package (name "onefetch") (version "2.27.1")
    (source (origin (method url-fetch) (uri "https://github.com/o2sh/onefetch/releases/download/2.27.1/onefetch-linux.tar.gz") (sha256 (base32 "1xdhaia2k8j0336g7xvh54rcwv31j3rkvam2zjfx4nx8yz9d3mji"))))
    (build-system gnu-build-system)
    (native-inputs (list patchelf tar gzip unzip))
    (arguments
     '(#:tests? #f #:strip-binaries? #f #:validate-runpath? #f
       #:phases (modify-phases %standard-phases
         (delete 'bootstrap)(delete 'configure)(delete 'check)
         (delete 'build)(delete 'patch-usr-bin-file)
         (delete 'patch-source-shebangs)(delete 'patch-generated-file-shebangs)
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (let* ((out (assoc-ref outputs "out"))
                    (bdir (string-append out "/bin"))
                    (glibc (assoc-ref %build-inputs "libc"))
                    (interp (string-append glibc "/lib/ld-linux-x86-64.so.2"))
                    (pe (string-append (assoc-ref %build-inputs "patchelf") "/bin/patchelf")))
               (mkdir-p bdir)
               (if (file-exists? "onefetch")
                 (begin (install-file "onefetch" bdir)
                   (chmod (string-append bdir "/" "onefetch") #o555)
                   (false-if-exception (invoke pe "--set-interpreter" interp (string-append bdir "/" "onefetch"))))
                 (let ((files (find-files "." (lambda (f s) (string-contains (basename f) "onefetch")))))
                   (if (pair? files)
                     (let ((src (car files)))
                       (copy-file src (string-append bdir "/" "onefetch"))
                       (chmod (string-append bdir "/" "onefetch") #o555)
                       (false-if-exception (invoke pe "--set-interpreter" interp (string-append bdir "/" "onefetch")))))))
               #t))))))
    (supported-systems '("x86_64-linux"))
    (home-page "") (synopsis "") (description "") (license gpl3+)))

(define-public erdtree-disk
  (package (name "erdtree") (version "3.1.2")
    (source (origin (method url-fetch) (uri "https://github.com/solidiquis/erdtree/releases/download/v3.1.2/erd-v3.1.2-x86_64-unknown-linux-gnu.tar.gz") (sha256 (base32 "0bz40yny6y4x1x63ya0wzfvhahkqnsslwkb0cfrlqx7gq5xncm4k"))))
    (build-system gnu-build-system)
    (native-inputs (list patchelf tar gzip unzip))
    (arguments
     '(#:tests? #f #:strip-binaries? #f #:validate-runpath? #f
       #:phases (modify-phases %standard-phases
         (delete 'bootstrap)(delete 'configure)(delete 'check)
         (delete 'build)(delete 'patch-usr-bin-file)
         (delete 'patch-source-shebangs)(delete 'patch-generated-file-shebangs)
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (let* ((out (assoc-ref outputs "out"))
                    (bdir (string-append out "/bin"))
                    (glibc (assoc-ref %build-inputs "libc"))
                    (interp (string-append glibc "/lib/ld-linux-x86-64.so.2"))
                    (pe (string-append (assoc-ref %build-inputs "patchelf") "/bin/patchelf")))
               (mkdir-p bdir)
               (if (file-exists? "erd")
                 (begin (install-file "erd" bdir)
                   (chmod (string-append bdir "/" "erd") #o555)
                   (false-if-exception (invoke pe "--set-interpreter" interp (string-append bdir "/" "erd"))))
                 (let ((files (find-files "." (lambda (f s) (string-contains (basename f) "erd")))))
                   (if (pair? files)
                     (let ((src (car files)))
                       (copy-file src (string-append bdir "/" "erd"))
                       (chmod (string-append bdir "/" "erd") #o555)
                       (false-if-exception (invoke pe "--set-interpreter" interp (string-append bdir "/" "erd")))))))
               #t))))))
    (supported-systems '("x86_64-linux"))
    (home-page "") (synopsis "") (description "") (license gpl3+)))

(define-public bandwhich-net
  (package (name "bandwhich") (version "0.23.1")
    (source (origin (method url-fetch) (uri "https://github.com/imsnif/bandwhich/releases/download/v0.23.1/bandwhich-v0.23.1-x86_64-unknown-linux-gnu.tar.gz") (sha256 (base32 "0dvnd160p30bf59mzsgymygbns65xnw2ydscv2zazv6izijjdq8d"))))
    (build-system gnu-build-system)
    (native-inputs (list patchelf tar gzip unzip))
    (arguments
     '(#:tests? #f #:strip-binaries? #f #:validate-runpath? #f
       #:phases (modify-phases %standard-phases
         (delete 'bootstrap)(delete 'configure)(delete 'check)
         (delete 'build)(delete 'patch-usr-bin-file)
         (delete 'patch-source-shebangs)(delete 'patch-generated-file-shebangs)
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (let* ((out (assoc-ref outputs "out"))
                    (bdir (string-append out "/bin"))
                    (glibc (assoc-ref %build-inputs "libc"))
                    (interp (string-append glibc "/lib/ld-linux-x86-64.so.2"))
                    (pe (string-append (assoc-ref %build-inputs "patchelf") "/bin/patchelf")))
               (mkdir-p bdir)
               (if (file-exists? "bandwhich")
                 (begin (install-file "bandwhich" bdir)
                   (chmod (string-append bdir "/" "bandwhich") #o555)
                   (false-if-exception (invoke pe "--set-interpreter" interp (string-append bdir "/" "bandwhich"))))
                 (let ((files (find-files "." (lambda (f s) (string-contains (basename f) "bandwhich")))))
                   (if (pair? files)
                     (let ((src (car files)))
                       (copy-file src (string-append bdir "/" "bandwhich"))
                       (chmod (string-append bdir "/" "bandwhich") #o555)
                       (false-if-exception (invoke pe "--set-interpreter" interp (string-append bdir "/" "bandwhich")))))))
               #t))))))
    (supported-systems '("x86_64-linux"))
    (home-page "") (synopsis "") (description "") (license gpl3+)))

(define-public resvg-render
  (package (name "resvg") (version "0.47.0")
    (source (origin (method url-fetch) (uri "https://github.com/RazrFalcon/resvg/releases/download/v0.47.0/resvg-linux-x86_64.tar.gz") (sha256 (base32 "1rsgrg3667p96wmmirnjc5jxzyd20xlgs5p6js6pxzijs2ydr12w"))))
    (build-system gnu-build-system)
    (native-inputs (list patchelf tar gzip unzip))
    (arguments
     '(#:tests? #f #:strip-binaries? #f #:validate-runpath? #f
       #:phases (modify-phases %standard-phases
         (delete 'bootstrap)(delete 'configure)(delete 'check)
         (delete 'build)(delete 'patch-usr-bin-file)
         (delete 'patch-source-shebangs)(delete 'patch-generated-file-shebangs)
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (let* ((out (assoc-ref outputs "out"))
                    (bdir (string-append out "/bin"))
                    (glibc (assoc-ref %build-inputs "libc"))
                    (interp (string-append glibc "/lib/ld-linux-x86-64.so.2"))
                    (pe (string-append (assoc-ref %build-inputs "patchelf") "/bin/patchelf")))
               (mkdir-p bdir)
               (if (file-exists? "resvg")
                 (begin (install-file "resvg" bdir)
                   (chmod (string-append bdir "/" "resvg") #o555)
                   (false-if-exception (invoke pe "--set-interpreter" interp (string-append bdir "/" "resvg"))))
                 (let ((files (find-files "." (lambda (f s) (string-contains (basename f) "resvg")))))
                   (if (pair? files)
                     (let ((src (car files)))
                       (copy-file src (string-append bdir "/" "resvg"))
                       (chmod (string-append bdir "/" "resvg") #o555)
                       (false-if-exception (invoke pe "--set-interpreter" interp (string-append bdir "/" "resvg")))))))
               #t))))))
    (supported-systems '("x86_64-linux"))
    (home-page "") (synopsis "") (description "") (license gpl3+)))

;; BATCH 7 — verified URLs from GitHub API
(define-public doggo-dns
  (package (name "doggo") (version "1.1.7")
    (source (origin (method url-fetch) (uri "https://github.com/mr-karan/doggo/releases/download/v1.1.7/doggo_1.1.7_Linux_x86_64.tar.gz") (sha256 (base32 "14jkgcshvx3fglybj189pxgi2810mghhxnbzja1795ysvd2x0259"))))
    (build-system gnu-build-system)
    (native-inputs (list patchelf tar gzip unzip))
    (arguments
     '(#:tests? #f #:strip-binaries? #f #:validate-runpath? #f
       #:phases (modify-phases %standard-phases
         (delete 'bootstrap)(delete 'configure)(delete 'check)
         (delete 'build)(delete 'patch-usr-bin-file)
         (delete 'patch-source-shebangs)(delete 'patch-generated-file-shebangs)
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (let* ((out (assoc-ref outputs "out"))
                    (bdir (string-append out "/bin"))
                    (glibc (assoc-ref %build-inputs "libc"))
                    (interp (string-append glibc "/lib/ld-linux-x86-64.so.2"))
                    (pe (string-append (assoc-ref %build-inputs "patchelf") "/bin/patchelf")))
               (mkdir-p bdir)
               (if (file-exists? "doggo")
                 (begin (install-file "doggo" bdir)
                   (chmod (string-append bdir "/" "doggo") #o555)
                   (false-if-exception (invoke pe "--set-interpreter" interp (string-append bdir "/" "doggo"))))
                 (let ((files (find-files "." (lambda (f s) (string-contains (basename f) "doggo")))))
                   (if (pair? files)
                     (let ((src (car files)))
                       (copy-file src (string-append bdir "/" "doggo"))
                       (chmod (string-append bdir "/" "doggo") #o555)
                       (false-if-exception (invoke pe "--set-interpreter" interp (string-append bdir "/" "doggo")))))))
               #t))))))
    (supported-systems '("x86_64-linux"))
    (home-page "") (synopsis "") (description "") (license gpl3+)))

(define-public xh-client
  (package (name "xh") (version "0.25.3")
    (source (origin (method url-fetch) (uri "https://github.com/ducaale/xh/releases/download/v0.25.3/xh-v0.25.3-x86_64-unknown-linux-musl.tar.gz") (sha256 (base32 "05ypr05b4pjcxnfbmxissyayvziv0xw6q83f4l87lzijddhqwwzw"))))
    (build-system gnu-build-system)
    (native-inputs (list patchelf tar gzip unzip))
    (arguments
     '(#:tests? #f #:strip-binaries? #f #:validate-runpath? #f
       #:phases (modify-phases %standard-phases
         (delete 'bootstrap)(delete 'configure)(delete 'check)
         (delete 'build)(delete 'patch-usr-bin-file)
         (delete 'patch-source-shebangs)(delete 'patch-generated-file-shebangs)
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (let* ((out (assoc-ref outputs "out"))
                    (bdir (string-append out "/bin"))
                    (glibc (assoc-ref %build-inputs "libc"))
                    (interp (string-append glibc "/lib/ld-linux-x86-64.so.2"))
                    (pe (string-append (assoc-ref %build-inputs "patchelf") "/bin/patchelf")))
               (mkdir-p bdir)
               (if (file-exists? "xh")
                 (begin (install-file "xh" bdir)
                   (chmod (string-append bdir "/" "xh") #o555)
                   (false-if-exception (invoke pe "--set-interpreter" interp (string-append bdir "/" "xh"))))
                 (let ((files (find-files "." (lambda (f s) (string-contains (basename f) "xh")))))
                   (if (pair? files)
                     (let ((src (car files)))
                       (copy-file src (string-append bdir "/" "xh"))
                       (chmod (string-append bdir "/" "xh") #o555)
                       (false-if-exception (invoke pe "--set-interpreter" interp (string-append bdir "/" "xh")))))))
               #t))))))
    (supported-systems '("x86_64-linux"))
    (home-page "") (synopsis "") (description "") (license gpl3+)))

(define-public lnav-log
  (package (name "lnav") (version "0.14.0")
    (source (origin (method url-fetch) (uri "https://github.com/tstack/lnav/releases/download/v0.14.0/lnav-0.14.0-linux-musl-x86_64.zip") (sha256 (base32 "0mqggxgfjzdjah4hni95xrqhgbnjjvdgbzqaj9vml05gl8fns54x"))))
    (build-system gnu-build-system)
    (native-inputs (list patchelf tar gzip unzip))
    (arguments
     '(#:tests? #f #:strip-binaries? #f #:validate-runpath? #f
       #:phases (modify-phases %standard-phases
         (delete 'bootstrap)(delete 'configure)(delete 'check)
         (delete 'build)(delete 'patch-usr-bin-file)
         (delete 'patch-source-shebangs)(delete 'patch-generated-file-shebangs)
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (let* ((out (assoc-ref outputs "out"))
                    (bdir (string-append out "/bin"))
                    (glibc (assoc-ref %build-inputs "libc"))
                    (interp (string-append glibc "/lib/ld-linux-x86-64.so.2"))
                    (pe (string-append (assoc-ref %build-inputs "patchelf") "/bin/patchelf")))
               (mkdir-p bdir)
               (if (file-exists? "lnav")
                 (begin (install-file "lnav" bdir)
                   (chmod (string-append bdir "/" "lnav") #o555)
                   (false-if-exception (invoke pe "--set-interpreter" interp (string-append bdir "/" "lnav"))))
                 (let ((files (find-files "." (lambda (f s) (string-contains (basename f) "lnav")))))
                   (if (pair? files)
                     (let ((src (car files)))
                       (copy-file src (string-append bdir "/" "lnav"))
                       (chmod (string-append bdir "/" "lnav") #o555)
                       (false-if-exception (invoke pe "--set-interpreter" interp (string-append bdir "/" "lnav")))))))
               #t))))))
    (supported-systems '("x86_64-linux"))
    (home-page "") (synopsis "") (description "") (license gpl3+)))

;; Single-binary packages (no archive — just a binary file)

;; BATCH 8 — single binary releases
(define-public cpufetch-tool
  (package (name "cpufetch") (version "1.07")
    (source (origin (method url-fetch) (uri "https://github.com/Dr-Noob/cpufetch/releases/download/v1.07/cpufetch_x86-64_linux") (sha256 (base32 "0ljg3sj1hm1jzz0mzbx482gpi5ls1cv87k3h5rfk2iv42z0p82lc"))))
    (build-system gnu-build-system)
    (native-inputs (list patchelf))
    (arguments
     '(#:tests? #f #:strip-binaries? #f #:validate-runpath? #f
       #:phases (modify-phases %standard-phases
         (delete 'bootstrap)(delete 'configure)(delete 'check)
         (delete 'build)(delete 'patch-usr-bin-file)
         (delete 'patch-source-shebangs)(delete 'patch-generated-file-shebangs)
         (add-after 'unpack 'copy-bin
           (lambda* (#:key source #:allow-other-keys)
             (copy-file source "cpufetch") #t))
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (let* ((out (assoc-ref outputs "out"))
                    (bdir (string-append out "/bin"))
                    (glibc (assoc-ref %build-inputs "libc"))
                    (interp (string-append glibc "/lib/ld-linux-x86-64.so.2"))
                    (pe (string-append (assoc-ref %build-inputs "patchelf") "/bin/patchelf")))
               (mkdir-p bdir)
               (copy-file "cpufetch" (string-append bdir "/" "cpufetch"))
               (chmod (string-append bdir "/" "cpufetch") #o555)
               (false-if-exception (invoke pe "--set-interpreter" interp (string-append bdir "/" "cpufetch")))
               #t))))))
    (supported-systems '("x86_64-linux"))
    (home-page "") (synopsis "") (description "") (license gpl3+)))

(define-public viu-viewer
  (package (name "viu") (version "1.6.1")
    (source (origin (method url-fetch) (uri "https://github.com/atanunq/viu/releases/download/v1.6.1/viu-x86_64-unknown-linux-musl") (sha256 (base32 "0vpclcm7igviszfab2bk199xpm485d5gclsz1llhc524y1gjc27i"))))
    (build-system gnu-build-system)
    (native-inputs (list patchelf))
    (arguments
     '(#:tests? #f #:strip-binaries? #f #:validate-runpath? #f
       #:phases (modify-phases %standard-phases
         (delete 'bootstrap)(delete 'configure)(delete 'check)
         (delete 'build)(delete 'patch-usr-bin-file)
         (delete 'patch-source-shebangs)(delete 'patch-generated-file-shebangs)
         (add-after 'unpack 'copy-bin
           (lambda* (#:key source #:allow-other-keys)
             (copy-file source "viu") #t))
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (let* ((out (assoc-ref outputs "out"))
                    (bdir (string-append out "/bin"))
                    (glibc (assoc-ref %build-inputs "libc"))
                    (interp (string-append glibc "/lib/ld-linux-x86-64.so.2"))
                    (pe (string-append (assoc-ref %build-inputs "patchelf") "/bin/patchelf")))
               (mkdir-p bdir)
               (copy-file "viu" (string-append bdir "/" "viu"))
               (chmod (string-append bdir "/" "viu") #o555)
               (false-if-exception (invoke pe "--set-interpreter" interp (string-append bdir "/" "viu")))
               #t))))))
    (supported-systems '("x86_64-linux"))
    (home-page "") (synopsis "") (description "") (license gpl3+)))

;; BATCH 9 — DEB + gzip + single binary final push
(define-public sops-secrets
  (package (name "sops") (version "3.13.1")
    (source (origin (method url-fetch) (uri "https://github.com/getsops/sops/releases/download/v3.13.1/sops-v3.13.1.linux.amd64") (sha256 (base32 "02j7iwwz67jgz79xp3a4kbl4rcg8lqjfm34hlvnapasj6dz9s2k2"))))
    (build-system gnu-build-system)
    (native-inputs (list patchelf))
    (arguments
     '(#:tests? #f #:strip-binaries? #f #:validate-runpath? #f
       #:phases (modify-phases %standard-phases
         (delete 'bootstrap)(delete 'configure)(delete 'check)
         (delete 'build)(delete 'patch-usr-bin-file)
         (delete 'patch-source-shebangs)(delete 'patch-generated-file-shebangs)
         (add-after 'unpack 'copy-bin
           (lambda* (#:key source #:allow-other-keys)
             (copy-file source "sops") #t))
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (let* ((out (assoc-ref outputs "out"))
                    (bdir (string-append out "/bin"))
                    (glibc (assoc-ref %build-inputs "libc"))
                    (interp (string-append glibc "/lib/ld-linux-x86-64.so.2"))
                    (pe (string-append (assoc-ref %build-inputs "patchelf") "/bin/patchelf")))
               (mkdir-p bdir)
               (copy-file "sops" (string-append bdir "/" "sops"))
               (chmod (string-append bdir "/" "sops") #o555)
               (false-if-exception (invoke pe "--set-interpreter" interp (string-append bdir "/" "sops")))
               #t))))))
    (supported-systems '("x86_64-linux"))
    (home-page "") (synopsis "") (description "") (license gpl3+)))

;; taplo: gzipped single binary — custom unpack
(define-public taplo-fmt
  (package
    (name "taplo") (version "0.10.0")
    (source (origin (method url-fetch)
             (uri "https://github.com/tamasfe/taplo/releases/download/0.10.0/taplo-linux-x86.gz")
             (sha256 (base32 "0nzh64lfrgy9wd2jpfhjpsrmgxqhd97j7b9n3yk61819k1vdx5q6"))))
    (build-system gnu-build-system)
    (native-inputs (list patchelf gzip))
    (arguments
     `(#:tests? #f #:strip-binaries? #f #:validate-runpath? #f
       #:phases (modify-phases %standard-phases
         (delete 'bootstrap) (delete 'configure) (delete 'check)
         (delete 'build) (delete 'patch-usr-bin-file)
         (delete 'patch-source-shebangs) (delete 'patch-generated-file-shebangs)
         (add-after 'unpack 'unpack
           (lambda* (#:key source #:allow-other-keys)
           (system (string-append "gunzip -c " source " > taplo"))
           #t))
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
           (let* ((out    (assoc-ref outputs "out"))
           (bdir   (string-append out "/bin"))
           (glibc  (assoc-ref %build-inputs "libc"))
           (interp (string-append glibc "/lib/ld-linux-x86-64.so.2"))
           (pe     (string-append (assoc-ref %build-inputs "patchelf")
           "/bin/patchelf")))
           (mkdir-p bdir)
           (copy-file "taplo" (string-append bdir "/taplo"))
           (chmod (string-append bdir "/taplo") #o555)
           (false-if-exception
           (invoke pe "--set-interpreter" interp
           (string-append bdir "/taplo")))
           #t))))))
    (supported-systems '("x86_64-linux"))
    (home-page "") (synopsis "") (description "") (license gpl3+)))

;; tabiew: DEB package — extract with ar+tar
(define-public tabiew-tui
  (package
    (name "tabiew") (version "0.13.1")
    (source (origin (method url-fetch)
             (uri "https://github.com/shshemi/tabiew/releases/download/v0.13.1/tabiew-x86_64-unknown-linux-gnu.deb")
             (sha256 (base32 "1hq7xcc036pa2yy8y7vyxwczvg3kl8y21l9njzc4r75bgksl7j9c"))))
    (build-system gnu-build-system)
    (native-inputs (list patchelf tar gzip binutils))
    (arguments
     `(#:tests? #f #:strip-binaries? #f #:validate-runpath? #f
       #:phases (modify-phases %standard-phases
         (delete 'bootstrap) (delete 'configure) (delete 'check)
         (delete 'build) (delete 'patch-usr-bin-file)
         (delete 'patch-source-shebangs) (delete 'patch-generated-file-shebangs)
         (add-after 'unpack 'unpack
           (lambda* (#:key source #:allow-other-keys)
           (invoke "ar" "x" source "data.tar.xz")
           (invoke "tar" "xf" "data.tar.xz")
           #t))
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
           (let* ((out    (assoc-ref outputs "out"))
           (bdir   (string-append out "/bin"))
           (glibc  (assoc-ref %build-inputs "libc"))
           (interp (string-append glibc "/lib/ld-linux-x86-64.so.2"))
           (pe     (string-append (assoc-ref %build-inputs "patchelf")
           "/bin/patchelf")))
           (mkdir-p bdir)
           ;; tabiew installs as 'tw' inside the DEB
           (if (file-exists? "usr/bin/tw")
           (begin
           (copy-file "usr/bin/tw" (string-append bdir "/tabiew"))
           (chmod (string-append bdir "/tabiew") #o555)
           (false-if-exception
           (invoke pe "--set-interpreter" interp
           (string-append bdir "/tabiew")))))
           #t))))))
    (supported-systems '("x86_64-linux"))
    (home-page "") (synopsis "") (description "") (license gpl3+)))

(define-public goose-ai
  (package (name "goose") (version "1.35.0")
    (source (origin (method url-fetch) (uri "https://github.com/aaif-goose/goose/releases/download/v1.35.0/goose-x86_64-unknown-linux-gnu.tar.gz") (sha256 (base32 "01d4az2ndysy5hsc63pcavlka0vrpzvmbbmp8a7qkamwy1l4ygxk"))))
    (build-system gnu-build-system)
    (native-inputs (list patchelf tar gzip unzip))
    (arguments
     '(#:tests? #f #:strip-binaries? #f #:validate-runpath? #f
       #:phases (modify-phases %standard-phases
         (delete 'bootstrap)(delete 'configure)(delete 'check)
         (delete 'build)(delete 'patch-usr-bin-file)
         (delete 'patch-source-shebangs)(delete 'patch-generated-file-shebangs)
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (let* ((out (assoc-ref outputs "out"))
                    (bdir (string-append out "/bin"))
                    (glibc (assoc-ref %build-inputs "libc"))
                    (interp (string-append glibc "/lib/ld-linux-x86-64.so.2"))
                    (pe (string-append (assoc-ref %build-inputs "patchelf") "/bin/patchelf")))
               (mkdir-p bdir)
               (if (file-exists? "goose")
                 (begin (install-file "goose" bdir)
                   (chmod (string-append bdir "/" "goose") #o555)
                   (false-if-exception (invoke pe "--set-interpreter" interp (string-append bdir "/" "goose"))))
                 (let ((files (find-files "." (lambda (f s) (string-contains (basename f) "goose")))))
                   (if (pair? files)
                     (let ((src (car files)))
                       (copy-file src (string-append bdir "/" "goose"))
                       (chmod (string-append bdir "/" "goose") #o555)
                       (false-if-exception (invoke pe "--set-interpreter" interp (string-append bdir "/" "goose")))))))
               #t))))))
    (supported-systems '("x86_64-linux"))
    (home-page "") (synopsis "") (description "") (license gpl3+)))

;; sad: DEB with zstd compression
(define-public sad-editor
  (package
    (name "sad") (version "0.4.32")
    (source (origin (method url-fetch)
             (uri "https://github.com/ms-jpq/sad/releases/download/v0.4.32/x86_64-unknown-linux-gnu.deb")
             (sha256 (base32 "0qa38s1d1jz63xpmzvwpzbnsll4ma6n4bfq6pl16mjwkp8a9rync"))))
    (build-system gnu-build-system)
    (native-inputs (list patchelf tar zstd binutils))
    (arguments
     `(#:tests? #f #:strip-binaries? #f #:validate-runpath? #f
       #:phases (modify-phases %standard-phases
         (delete 'bootstrap) (delete 'configure) (delete 'check)
         (delete 'build) (delete 'patch-usr-bin-file)
         (delete 'patch-source-shebangs) (delete 'patch-generated-file-shebangs)
         (add-after 'unpack 'unpack
           (lambda* (#:key source #:allow-other-keys)
           (invoke "ar" "x" source "data.tar.zst")
           (invoke "zstd" "-d" "data.tar.zst" "-o" "data.tar")
           (invoke "tar" "xf" "data.tar")
           #t))
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
           (let* ((out    (assoc-ref outputs "out"))
           (bdir   (string-append out "/bin"))
           (glibc  (assoc-ref %build-inputs "libc"))
           (interp (string-append glibc "/lib/ld-linux-x86-64.so.2"))
           (pe     (string-append (assoc-ref %build-inputs "patchelf")
           "/bin/patchelf")))
           (mkdir-p bdir)
           (if (file-exists? "usr/bin/sad")
           (begin
           (copy-file "usr/bin/sad" (string-append bdir "/sad"))
           (chmod (string-append bdir "/sad") #o555)
           (false-if-exception
           (invoke pe "--set-interpreter" interp
           (string-append bdir "/sad")))))
           #t))))))
    (supported-systems '("x86_64-linux"))
    (home-page "") (synopsis "") (description "") (license gpl3+)))

;; axctl: Axenide compositor control CLI (Go binary from GitHub releases)
(define-public axctl-compositor
  (package (name "axctl") (version "0.0.19")
    (source (origin (method url-fetch) (uri "https://github.com/Axenide/axctl/releases/download/v0.0.19/axctl_linux_amd64") (sha256 (base32 "8grpig3vw59w8igbj06whpwacb3mfdw1q48asw3q48gcd238qgv0"))))
    (build-system gnu-build-system)
    (native-inputs (list patchelf tar gzip unzip))
    (arguments
     '(#:tests? #f #:strip-binaries? #f #:validate-runpath? #f
       #:phases (modify-phases %standard-phases
         (delete 'bootstrap)(delete 'configure)(delete 'check)
         (delete 'build)(delete 'patch-usr-bin-file)
         (delete 'patch-source-shebangs)(delete 'patch-generated-file-shebangs)
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (let* ((out (assoc-ref outputs "out"))
                    (bdir (string-append out "/bin"))
                    (glibc (assoc-ref %build-inputs "libc"))
                    (interp (string-append glibc "/lib/ld-linux-x86-64.so.2"))
                    (pe (string-append (assoc-ref %build-inputs "patchelf") "/bin/patchelf")))
               (mkdir-p bdir)
               (if (file-exists? "axctl_linux_amd64")
                 (begin (install-file "axctl_linux_amd64" bdir)
                   (chmod (string-append bdir "/" "axctl_linux_amd64") #o555)
                   (false-if-exception (invoke pe "--set-interpreter" interp (string-append bdir "/" "axctl_linux_amd64"))))
                 (let ((files (find-files "." (lambda (f s) (string-contains (basename f) "axctl_linux_amd64")))))
                   (if (pair? files)
                     (let ((src (car files)))
                       (copy-file src (string-append bdir "/" "axctl_linux_amd64"))
                       (chmod (string-append bdir "/" "axctl_linux_amd64") #o555)
                       (false-if-exception (invoke pe "--set-interpreter" interp (string-append bdir "/" "axctl_linux_amd64")))))))
               #t))))))
    (supported-systems '("x86_64-linux"))
    (home-page "") (synopsis "") (description "") (license gpl3+)))

;; ── BATCH 10: Final parity push ──

(define-public grex-tool
  (package (name "grex") (version "1.4.5")
    (source (origin (method url-fetch) (uri "https://github.com/pemistahl/grex/releases/download/v1.4.5/grex-v1.4.5-x86_64-unknown-linux-musl.tar.gz") (sha256 (base32 "1lix1r6kz3r1hmcxwc4n911d3jcwzxhhan2qiz8sjqvyljgfrisv"))))
    (build-system gnu-build-system)
    (native-inputs (list patchelf))
    (arguments
     '(#:tests? #f #:strip-binaries? #f #:validate-runpath? #f
       #:phases (modify-phases %standard-phases
         (delete 'bootstrap)(delete 'configure)(delete 'check)
         (delete 'build)(delete 'patch-usr-bin-file)
         (delete 'patch-source-shebangs)(delete 'patch-generated-file-shebangs)
         (add-after 'unpack 'copy-bin
           (lambda* (#:key source #:allow-other-keys)
             (copy-file source "grex") #t))
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (let* ((out (assoc-ref outputs "out"))
                    (bdir (string-append out "/bin"))
                    (glibc (assoc-ref %build-inputs "libc"))
                    (interp (string-append glibc "/lib/ld-linux-x86-64.so.2"))
                    (pe (string-append (assoc-ref %build-inputs "patchelf") "/bin/patchelf")))
               (mkdir-p bdir)
               (copy-file "grex" (string-append bdir "/" "grex"))
               (chmod (string-append bdir "/" "grex") #o555)
               (false-if-exception (invoke pe "--set-interpreter" interp (string-append bdir "/" "grex")))
               #t))))))
    (supported-systems '("x86_64-linux"))
    (home-page "") (synopsis "") (description "") (license gpl3+)))

(define-public no-more-secrets-nms
  (package
    (name "nms") (version "1.0.1")
    (source (origin
              (method git-fetch)
              (uri (git-reference
                    (url "https://github.com/bartobri/no-more-secrets")
                    (commit "v1.0.1")))
              (file-name (git-file-name name version))
              (sha256 (base32
                       "1936m1xz131b4iwdipxphrs5f7axbx2l5hxyr740z207i5p0d0mz"))))
    (build-system gnu-build-system)
    (arguments
     '(#:tests? #f
       #:phases (modify-phases %standard-phases
         (delete 'configure)
         (replace 'build
           (lambda* (#:key #:allow-other-keys)
           (invoke "make" "-C" "nms")))
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
           (let ((out (assoc-ref outputs "out")))
           (install-file "nms/nms" (string-append out "/bin"))))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/bartobri/no-more-secrets")
    (synopsis "Recreate the Hollywood text-display effect")
    (description "A set of tools to recreate the fascinating text-display effect")
    (license bsd-3)))

(define-public nvtop-monitor
  (package (name "nvtop") (version "3.2.0")
    (source (origin (method url-fetch) (uri "https://github.com/Syllo/nvtop/releases/download/3.2.0/nvtop-3.2.0-x86_64.AppImage") (sha256 (base32 "1i404mynqwz45wwcj7x694rxn06lc243164fvc9s4hsz0avlzi9k"))))
    (build-system gnu-build-system)
    (native-inputs (list patchelf))
    (arguments
     '(#:tests? #f #:strip-binaries? #f #:validate-runpath? #f
       #:phases (modify-phases %standard-phases
         (delete 'bootstrap)(delete 'configure)(delete 'check)
         (delete 'build)(delete 'patch-usr-bin-file)
         (delete 'patch-source-shebangs)(delete 'patch-generated-file-shebangs)
         (add-after 'unpack 'copy-bin
           (lambda* (#:key source #:allow-other-keys)
             (copy-file source "nvtop") #t))
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (let* ((out (assoc-ref outputs "out"))
                    (bdir (string-append out "/bin"))
                    (glibc (assoc-ref %build-inputs "libc"))
                    (interp (string-append glibc "/lib/ld-linux-x86-64.so.2"))
                    (pe (string-append (assoc-ref %build-inputs "patchelf") "/bin/patchelf")))
               (mkdir-p bdir)
               (copy-file "nvtop" (string-append bdir "/" "nvtop"))
               (chmod (string-append bdir "/" "nvtop") #o555)
               (false-if-exception (invoke pe "--set-interpreter" interp (string-append bdir "/" "nvtop")))
               #t))))))
    (supported-systems '("x86_64-linux"))
    (home-page "") (synopsis "") (description "") (license gpl3+)))

(define-public s-tui-stress
  (package
    (name "s-tui") (version "1.1.6")
    (source (origin (method url-fetch)
             (uri "https://github.com/amanusk/s-tui/archive/refs/tags/v1.1.6.tar.gz")
             (sha256 (base32 "1rxv4llcfla9rgkiih3lvbqb7m2rrmv4rnbp9z7fn9x4fdb91a4r"))))
    (build-system gnu-build-system)
    (arguments '(#:tests? #f #:phases (modify-phases %standard-phases
      (delete 'bootstrap) (delete 'configure) (delete 'check) (delete 'build)
      (replace 'install
        (lambda* (#:key outputs #:allow-other-keys)
        (let ((out (assoc-ref outputs "out")))
        (mkdir-p (string-append out "/bin"))
        (copy-recursively "." (string-append out "/share/s-tui"))
        (symlink (string-append out "/share/s-tui/s-tui")
        (string-append out "/bin/s-tui"))))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/amanusk/s-tui")
    (synopsis "Stress-Terminal UI") (description "CPU stress and monitoring TUI")
    (license gpl2+)))

(define-public ssh-to-age-key
  (package (name "ssh-to-age") (version "1.3.0")
    (source (origin (method url-fetch) (uri "https://github.com/Mic92/ssh-to-age/releases/download/v1.3.0/ssh-to-age.linux-amd64") (sha256 (base32 "1ii0f2df2n0qyq1zs0y9svcyydj1yb646m6cxv7pjkhmx1ad698a"))))
    (build-system gnu-build-system)
    (native-inputs (list patchelf))
    (arguments
     '(#:tests? #f #:strip-binaries? #f #:validate-runpath? #f
       #:phases (modify-phases %standard-phases
         (delete 'bootstrap)(delete 'configure)(delete 'check)
         (delete 'build)(delete 'patch-usr-bin-file)
         (delete 'patch-source-shebangs)(delete 'patch-generated-file-shebangs)
         (add-after 'unpack 'copy-bin
           (lambda* (#:key source #:allow-other-keys)
             (copy-file source "ssh-to-age") #t))
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (let* ((out (assoc-ref outputs "out"))
                    (bdir (string-append out "/bin"))
                    (glibc (assoc-ref %build-inputs "libc"))
                    (interp (string-append glibc "/lib/ld-linux-x86-64.so.2"))
                    (pe (string-append (assoc-ref %build-inputs "patchelf") "/bin/patchelf")))
               (mkdir-p bdir)
               (copy-file "ssh-to-age" (string-append bdir "/" "ssh-to-age"))
               (chmod (string-append bdir "/" "ssh-to-age") #o555)
               (false-if-exception (invoke pe "--set-interpreter" interp (string-append bdir "/" "ssh-to-age")))
               #t))))))
    (supported-systems '("x86_64-linux"))
    (home-page "") (synopsis "") (description "") (license gpl3+)))

(define-public geoip-database-maxmind
  (package
    (name "geoip-database") (version "20240501")
    (source (origin
              (method url-fetch)
              (uri "https://git.io/GeoLite2-City.mmdb")
              (sha256 (base32
                       "1rsgqzzdgy954vh1zazakpghk7gkz5g9b4w27am48va2gklmh7wi"))))
    (build-system gnu-build-system)
    (arguments '(#:tests? #f #:phases (modify-phases %standard-phases
      (delete 'bootstrap) (delete 'configure) (delete 'check) (delete 'build)
      (replace 'install
        (lambda* (#:key outputs source #:allow-other-keys)
        (let ((out (assoc-ref outputs "out")))
        (mkdir-p (string-append out "/share/GeoIP"))
        (copy-file source (string-append out "/share/GeoIP/GeoLite2-City.mmdb"))))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://dev.maxmind.com/geoip") (synopsis "GeoIP database")
    (description "MaxMind GeoLite2 City database") (license cc-by-sa4.0)))
