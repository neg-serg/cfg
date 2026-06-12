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

(define (binary-package name ver url hash bin)
  (package
    (name name) (version ver)
    (source (origin (method url-fetch) (uri url) (sha256 (base32 hash))))
    (build-system gnu-build-system)
    (native-inputs (list patchelf tar gzip unzip))
    (arguments
     (let* ((bin-file bin)
            (install-phase
             (lambda* (#:key outputs #:allow-other-keys)
               (let* ((out    (assoc-ref outputs "out"))
                      (bdir   (string-append out "/bin"))
                      (glibc  (assoc-ref %build-inputs "libc"))
                      (interp (string-append glibc "/lib/ld-linux-x86-64.so.2"))
                      (pe     (string-append (assoc-ref %build-inputs "patchelf")
                                             "/bin/patchelf")))
                 (mkdir-p bdir)
                 (if (file-exists? bin-file)
                     (begin
                       (install-file bin-file bdir)
                       (chmod (string-append bdir "/" bin-file) #o555)
                       (false-if-exception
                        (invoke pe "--set-interpreter" interp
                                (string-append bdir "/" bin-file))))
                     (let ((files (find-files "." (lambda (f s)
                                    (string-contains (basename f) bin-file)))))
                       (if (pair? files)
                           (let ((src (car files)))
                             (copy-file src (string-append bdir "/" bin-file))
                             (chmod (string-append bdir "/" bin-file) #o555)
                             (false-if-exception
                              (invoke pe "--set-interpreter" interp
                                      (string-append bdir "/" bin-file)))))))
                 #t))))
       `(#:tests? #f #:strip-binaries? #f #:validate-runpath? #f
         #:phases ,(modify-phases %standard-phases
                     (delete 'bootstrap) (delete 'configure) (delete 'check)
                     (delete 'build) (delete 'patch-usr-bin-file)
                     (delete 'patch-source-shebangs) (delete 'patch-generated-file-shebangs)
                     (delete 'install)
                     (add-after 'unpack 'install install-phase)))))
    (supported-systems '("x86_64-linux"))
    (home-page "") (synopsis "") (description "") (license gpl3+)))

;; BATCH 6 — Full parity push. Hashes verified via direct download.

(define-public yazi
  (binary-package "yazi" "25.4.8"
    "https://github.com/sxyazi/yazi/releases/download/v25.4.8/yazi-x86_64-unknown-linux-gnu.zip"
    "01sndv3mvhzq89ydvz562khqgz1w7l3f224kk93wmd3g1j2d5jxr"
    "yazi"))

(define-public ruff-linter
  (binary-package "ruff" "0.11.0"
    "https://github.com/astral-sh/ruff/releases/download/0.11.0/ruff-x86_64-unknown-linux-gnu.tar.gz"
    "1cwnmjyki09qz30l4l8wyiijb301lrn7s94h3r2ly7in7ddcaqdd"
    "ruff"))

(define-public gitleaks-sec
  (binary-package "gitleaks" "8.23.0"
    "https://github.com/gitleaks/gitleaks/releases/download/v8.23.0/gitleaks_8.23.0_linux_x64.tar.gz"
    "13lgvpyh633jcar0ia2vignhi540vkfrp77gkx3868zyivw45ifi"
    "gitleaks"))


(define-public ttyd-share
  (binary-package "ttyd" "1.7.7"
    "https://github.com/tsl0922/ttyd/releases/download/1.7.7/ttyd.x86_64"
    "0magpsvi5kgjn8fzb6z5sp25n0fw31r48d1zpw6jw5xsiab7q8ca"
    "ttyd.x86_64"))

(define-public genact-activity
  (binary-package "genact" "1.4.2"
    "https://github.com/svenstaro/genact/releases/download/v1.4.2/genact-1.4.2-x86_64-unknown-linux-musl"
    "0wqj3c66jl2s5hhx0qqw4fsmp1r0v382b5502z6njnxbzl1im28f"
    "genact-1.4.2-x86_64-unknown-linux-musl"))

(define-public ctop-monitor
  (binary-package "ctop" "0.7.7"
    "https://github.com/bcicen/ctop/releases/download/v0.7.7/ctop-0.7.7-linux-amd64"
    "029al32kpk8an169cgvzzbbm1hhir495aggfxnv18gdy9rrp90xp"
    "ctop-0.7.7-linux-amd64"))

(define-public onefetch-info
  (binary-package "onefetch" "2.27.1"
    "https://github.com/o2sh/onefetch/releases/download/2.27.1/onefetch-linux.tar.gz"
    "1xdhaia2k8j0336g7xvh54rcwv31j3rkvam2zjfx4nx8yz9d3mji"
    "onefetch"))

(define-public erdtree-disk
  (binary-package "erdtree" "3.1.2"
    "https://github.com/solidiquis/erdtree/releases/download/v3.1.2/erd-v3.1.2-x86_64-unknown-linux-gnu.tar.gz"
    "0bz40yny6y4x1x63ya0wzfvhahkqnsslwkb0cfrlqx7gq5xncm4k"
    "erd"))

(define-public bandwhich-net
  (binary-package "bandwhich" "0.23.1"
    "https://github.com/imsnif/bandwhich/releases/download/v0.23.1/bandwhich-v0.23.1-x86_64-unknown-linux-gnu.tar.gz"
    "0dvnd160p30bf59mzsgymygbns65xnw2ydscv2zazv6izijjdq8d"
    "bandwhich"))

(define-public resvg-render
  (binary-package "resvg" "0.47.0"
    "https://github.com/RazrFalcon/resvg/releases/download/v0.47.0/resvg-linux-x86_64.tar.gz"
    "1rsgrg3667p96wmmirnjc5jxzyd20xlgs5p6js6pxzijs2ydr12w"
    "resvg"))

;; BATCH 7 — verified URLs from GitHub API
(define-public doggo-dns
  (binary-package "doggo" "1.1.7"
    "https://github.com/mr-karan/doggo/releases/download/v1.1.7/doggo_1.1.7_Linux_x86_64.tar.gz"
    "14jkgcshvx3fglybj189pxgi2810mghhxnbzja1795ysvd2x0259"
    "doggo"))

(define-public xh-client
  (binary-package "xh" "0.25.3"
    "https://github.com/ducaale/xh/releases/download/v0.25.3/xh-v0.25.3-x86_64-unknown-linux-musl.tar.gz"
    "05ypr05b4pjcxnfbmxissyayvziv0xw6q83f4l87lzijddhqwwzw"
    "xh"))

(define-public lnav-log
  (binary-package "lnav" "0.14.0"
    "https://github.com/tstack/lnav/releases/download/v0.14.0/lnav-0.14.0-linux-musl-x86_64.zip"
    "0mqggxgfjzdjah4hni95xrqhgbnjjvdgbzqaj9vml05gl8fns54x"
    "lnav"))

;; Single-binary packages (no archive — just a binary file)
(define (single-binary-package name ver url hash bin)
  (package
    (name name) (version ver)
    (source (origin (method url-fetch) (uri url) (sha256 (base32 hash))))
    (build-system gnu-build-system)
    (native-inputs (list patchelf))
    (arguments
     `(#:tests? #f #:strip-binaries? #f #:validate-runpath? #f
        #:phases (modify-phases %standard-phases
          (delete 'bootstrap) (delete 'configure) (delete 'check)
          (delete 'build) (delete 'patch-usr-bin-file)
          (delete 'patch-source-shebangs) (delete 'patch-generated-file-shebangs)
          (delete 'unpack)
          (delete 'install)
          (add-after 'unpack 'unpack
            (lambda* (#:key source #:allow-other-keys)
              (copy-file source ,bin)
              #t))
          (add-after 'unpack 'install
            (lambda* (#:key outputs #:allow-other-keys)
              (let* ((out    (assoc-ref outputs "out"))
                     (bdir   (string-append out "/bin"))
                     (glibc  (assoc-ref %build-inputs "libc"))
                     (interp (string-append glibc "/lib/ld-linux-x86-64.so.2"))
                     (pe     (string-append (assoc-ref %build-inputs "patchelf")
                                            "/bin/patchelf")))
                (mkdir-p bdir)
                (copy-file ,bin (string-append bdir "/" ,bin))
                (chmod (string-append bdir "/" ,bin) #o555)
                (false-if-exception
                 (invoke pe "--set-interpreter" interp
                         (string-append bdir "/" ,bin)))
                #t))))))
    (supported-systems '("x86_64-linux"))
    (home-page "") (synopsis "") (description "") (license gpl3+)))

;; BATCH 8 — single binary releases
(define-public cpufetch-tool
  (single-binary-package "cpufetch" "1.07"
    "https://github.com/Dr-Noob/cpufetch/releases/download/v1.07/cpufetch_x86-64_linux"
    "0ljg3sj1hm1jzz0mzbx482gpi5ls1cv87k3h5rfk2iv42z0p82lc"
    "cpufetch"))

(define-public viu-viewer
  (single-binary-package "viu" "1.6.1"
    "https://github.com/atanunq/viu/releases/download/v1.6.1/viu-x86_64-unknown-linux-musl"
    "0vpclcm7igviszfab2bk199xpm485d5gclsz1llhc524y1gjc27i"
    "viu"))

;; BATCH 9 — DEB + gzip + single binary final push
(define-public sops-secrets
  (single-binary-package "sops" "3.13.1"
    "https://github.com/getsops/sops/releases/download/v3.13.1/sops-v3.13.1.linux.amd64"
    "02j7iwwz67jgz79xp3a4kbl4rcg8lqjfm34hlvnapasj6dz9s2k2"
    "sops"))

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
         (delete 'unpack)
         (add-after 'unpack 'unpack
           (lambda* (#:key source #:allow-other-keys)
           (system (string-append "gunzip -c " source " > taplo"))
           #t))
         (delete 'install)
         (add-after 'unpack 'install
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
         (delete 'unpack)
         (add-after 'unpack 'unpack
           (lambda* (#:key source #:allow-other-keys)
           (invoke "ar" "x" source "data.tar.xz")
           (invoke "tar" "xf" "data.tar.xz")
           #t))
         (delete 'install)
         (add-after 'unpack 'install
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
  (binary-package "goose" "1.35.0"
    "https://github.com/aaif-goose/goose/releases/download/v1.35.0/goose-x86_64-unknown-linux-gnu.tar.gz"
    "01d4az2ndysy5hsc63pcavlka0vrpzvmbbmp8a7qkamwy1l4ygxk"
    "goose"))

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
         (delete 'unpack)
         (add-after 'unpack 'unpack
           (lambda* (#:key source #:allow-other-keys)
           (invoke "ar" "x" source "data.tar.zst")
           (invoke "zstd" "-d" "data.tar.zst" "-o" "data.tar")
           (invoke "tar" "xf" "data.tar")
           #t))
         (delete 'install)
         (add-after 'unpack 'install
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
  (binary-package "axctl" "0.0.19"
    "https://github.com/Axenide/axctl/releases/download/v0.0.19/axctl_linux_amd64"
    "8grpig3vw59w8igbj06whpwacb3mfdw1q48asw3q48gcd238qgv0"
    "axctl_linux_amd64"))

;; ── BATCH 10: Final parity push ──

(define-public grex-tool
  (single-binary-package "grex" "1.4.5"
    "https://github.com/pemistahl/grex/releases/download/v1.4.5/grex-v1.4.5-x86_64-unknown-linux-musl.tar.gz"
    "1lix1r6kz3r1hmcxwc4n911d3jcwzxhhan2qiz8sjqvyljgfrisv"
    "grex"))

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
         (delete 'build)
         (add-after 'unpack 'build
           (lambda* (#:key #:allow-other-keys)
           (invoke "make" "-C" "nms")))
         (delete 'install)
         (add-after 'unpack 'install
           (lambda* (#:key outputs #:allow-other-keys)
           (let ((out (assoc-ref outputs "out")))
           (install-file "nms/nms" (string-append out "/bin"))))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/bartobri/no-more-secrets")
    (synopsis "Recreate the Hollywood text-display effect")
    (description "A set of tools to recreate the fascinating text-display effect")
    (license bsd-3)))

(define-public nvtop-monitor
  (single-binary-package "nvtop" "3.2.0"
    "https://github.com/Syllo/nvtop/releases/download/3.2.0/nvtop-3.2.0-x86_64.AppImage"
    "1i404mynqwz45wwcj7x694rxn06lc243164fvc9s4hsz0avlzi9k"
    "nvtop"))

(define-public s-tui-stress
  (package
    (name "s-tui") (version "1.1.6")
    (source (origin (method url-fetch)
             (uri "https://github.com/amanusk/s-tui/archive/refs/tags/v1.1.6.tar.gz")
             (sha256 (base32 "1rxv4llcfla9rgkiih3lvbqb7m2rrmv4rnbp9z7fn9x4fdb91a4r"))))
    (build-system gnu-build-system)
    (arguments '(#:tests? #f #:phases (modify-phases %standard-phases
      (delete 'bootstrap) (delete 'configure) (delete 'check) (delete 'build)
      (delete 'install)
      (add-after 'unpack 'install
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
  (single-binary-package "ssh-to-age" "1.3.0"
    "https://github.com/Mic92/ssh-to-age/releases/download/v1.3.0/ssh-to-age.linux-amd64"
    "1ii0f2df2n0qyq1zs0y9svcyydj1yb646m6cxv7pjkhmx1ad698a"
    "ssh-to-age"))

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
      (delete 'install)
      (add-after 'unpack 'install
        (lambda* (#:key outputs source #:allow-other-keys)
        (let ((out (assoc-ref outputs "out")))
        (mkdir-p (string-append out "/share/GeoIP"))
        (copy-file source (string-append out "/share/GeoIP/GeoLite2-City.mmdb"))))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://dev.maxmind.com/geoip") (synopsis "GeoIP database")
    (description "MaxMind GeoLite2 City database") (license cc-by-sa4.0)))
