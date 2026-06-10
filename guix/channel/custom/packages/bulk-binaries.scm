(define-module (custom packages bulk-binaries)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses)
  #:use-module (gnu packages elf)
  #:use-module (gnu packages base)
  #:use-module (gnu packages compression))

(define (binary-package name ver url hash bin)
  (package
    (name name) (version ver)
    (source (origin (method url-fetch) (uri url) (sha256 (base32 hash))))
    (build-system gnu-build-system)
    (native-inputs (list patchelf tar gzip unzip))
    (arguments
     `(#:tests? #f #:strip-binaries? #f #:validate-runpath? #f
       #:phases (modify-phases %standard-phases
         (delete 'bootstrap) (delete 'configure) (delete 'check)
         (delete 'build) (delete 'patch-usr-bin-file)
         (delete 'patch-source-shebangs) (delete 'patch-generated-file-shebangs)
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (let* ((out    (assoc-ref outputs "out"))
                    (bdir   (string-append out "/bin"))
                    (glibc  (assoc-ref %build-inputs "libc"))
                    (interp (string-append glibc "/lib/ld-linux-x86-64.so.2"))
                    (pe     (string-append (assoc-ref %build-inputs "patchelf")
                                           "/bin/patchelf")))
               (mkdir-p bdir)
               (if (file-exists? ,bin)
                   (begin
                     (install-file ,bin bdir)
                     (chmod (string-append bdir "/" ,bin) #o555)
                     (false-if-exception
                      (invoke pe "--set-interpreter" interp
                              (string-append bdir "/" ,bin))))
                   (let ((files (find-files "." (lambda (f s)
                                  (string-contains (basename f) ,bin)))))
                     (if (pair? files)
                         (let ((src (car files)))
                           (copy-file src (string-append bdir "/" ,bin))
                           (chmod (string-append bdir "/" ,bin) #o555)
                           (false-if-exception
                            (invoke pe "--set-interpreter" interp
                                    (string-append bdir "/" ,bin)))))))
               #t))))))
    (supported-systems '("x86_64-linux"))
    (home-page "") (synopsis "") (description "") (license gpl3+)))

;; ====== PACKAGES ======
(define-public gowall
  (binary-package "gowall" "0.2.4"
    "https://github.com/Achno/gowall/releases/download/v0.2.4/gowall-amd64-linux.tar.gz"
    "1lsasg11awds6bb4pvxd046hnry55812dpcjpl7pjpwf0baqdd6s"
    "gowall"))

(define-public localsend
  (binary-package "localsend" "1.17.0"
    "https://github.com/localsend/localsend/releases/download/v1.17.0/LocalSend-1.17.0-linux-x86-64.tar.gz"
    "10ccgycq1c6m0wkakfkqc8pv4kf3c5d6ni6kck3smgidnx8yh1bg"
    "localsend"))

(define-public freeze
  (binary-package "freeze" "0.2.2"
    "https://github.com/charmbracelet/freeze/releases/download/v0.2.2/freeze_0.2.2_Linux_x86_64.tar.gz"
    "16skacpljnfcfi9v0rdmsg8dg4vds4saqah5z5q9bhf02vfxnbq1"
    "freeze"))

(define-public lutgen
  (binary-package "lutgen" "1.1.1"
    "https://github.com/ozwaldorf/lutgen-rs/releases/download/lutgen-v1.1.1/lutgen-cli-v1.1.1-x86_64-unknown-linux-gnu"
    "180vlbk2rl9dwbj8bbf6hz445nnvk34ycfyr065k1csimvp0nq8h"
    "lutgen-cli-v1.1.1-x86_64-unknown-linux-gnu"))

(define-public fsel
  (binary-package "fsel" "3.5.1"
    "https://github.com/Mjoyufull/fsel/releases/download/3.5.1/fsel-x86_64-unknown-linux-gnu.tar.xz"
    "12bhkjjs3x3vaxqsp8qrgw5m2v86zhi0rj5rrx8h6nqjh4gxars7"
    "fsel"))

(define-public simutil
  (binary-package "simutil" "0.5.0"
    "https://github.com/dungngminh/simutil/releases/download/v0.5.0/simutil-linux-x64.tar.gz"
    "141d23vp4gjr2bxzdq5ipmflgq7raqvkzsv7b1v7d98xjaqw6ajb"
    "simutil"))

(define-public reddix
  (binary-package "reddix" "0.2.9"
    "https://github.com/ck-zhang/reddix/releases/download/v0.2.9/reddix-x86_64-unknown-linux-gnu.tar.xz"
    "00cj2w9x8qa8f3cnhbakp4g1rqg12anrlz0c3gafggr9czz9a4ax"
    "reddix"))

(define-public repeater
  (binary-package "repeater" "0.1.10"
    "https://github.com/shaankhosla/repeater/releases/download/v0.1.10/repeater-x86_64-unknown-linux-gnu.tar.xz"
    "09mhgf0fywfnxaac4w0s7dhmgk49ka5bjpjqp94r7d3kd070v7ng"
    "repeater"))

(define-public lazytail
  (binary-package "lazytail" "0.10.0"
    "https://github.com/raaymax/lazytail/releases/download/v0.10.0/lazytail-linux-x86_64.tar.gz"
    "0r4d07bj8q4c6x1v7g7jl8ay2vh7wwz1mbqwc7vy9s89qn37ikra"
    "lazytail"))

(define-public gmap
  (binary-package "gmap" "0.4.0"
    "https://github.com/seeyebe/gmap/releases/download/v0.4.0/gmap-linux-x86_64-0.4.0.zip"
    "18nyd47bapynq72ksgs0i2yqhj3c1iaiav2bmmsc7l7jddjl7xpv"
    "gmap"))

(define-public watchtower
  (binary-package "watchtower" "1.0.0"
    "https://github.com/lajosdeme/watchtower/releases/download/v1.0.0/watchtower_Linux_x86_64.tar.gz"
    "1c9r7yz50rlww7q1kfx3fybxa936hj214m81vn9i71w8ix1la5gk"
    "watchtower"))

(define-public hxd
  (binary-package "hxd" "1.0.0"
    "https://github.com/kiedtl/huxdemp/releases/download/1.0.0/huxd-Linux-x86_64-1.0.0.tar.xz"
    "0m2x2b0h6jblns8wh2dg90cy8zg8m82fd2zbhp5b6rhkjd5rn9p7"
    "huxd"))

(define-public oh-my-posh
  (binary-package "oh-my-posh" "29.13.1"
    "https://github.com/JanDeDobbeleer/oh-my-posh/releases/download/v29.13.1/posh-linux-amd64"
    "1fgn7sc8hpgkp01zvm4pm48l6iy36hv0ckg4ns6mvikn2idr6d37"
    "posh-linux-amd64"))

;; ====== BATCH 2 ======
(define-public act-bin
  (binary-package "act" "0.2.88"
    "https://github.com/nektos/act/releases/download/v0.2.88/act_Linux_x86_64.tar.gz"
    "1cx2ccy6fgd05pc155r2zk6z0xh3qlp0zygkr0x0bk6zh9k9kf8y"
    "act"))

(define-public babashka
  (binary-package "babashka" "1.12.218"
    "https://github.com/babashka/babashka/releases/download/v1.12.218/babashka-1.12.218-linux-amd64-static.tar.gz"
    "1y6srnrz9i6zm296y17iaj73r2a0k0vy87537pggycj7g762il3v"
    "bb"))

(define-public carapace-bin
  (binary-package "carapace" "1.6.6"
    "https://github.com/carapace-sh/carapace-bin/releases/download/v1.6.6/carapace-bin_1.6.6_linux_amd64.tar.gz"
    "0svpbxgssc9zfcpg89f5dn6523kz4zyaxn4583zkp80vacq8l773"
    "carapace"))

(define-public eilmeldung
  (binary-package "eilmeldung" "1.5.2"
    "https://github.com/christo-auer/eilmeldung/releases/download/1.5.2/eilmeldung-x86_64-unknown-linux-musl-1.5.2.tar.gz"
    "1z1601pqayan41hb8yyly98y0v2lwkbknrsm60l97mp6ff8cdh8q"
    "eilmeldung"))

(define-public ghgrab
  (binary-package "ghgrab" "1.3.2"
    "https://github.com/abhixdd/ghgrab/releases/download/v1.3.2/ghgrab-linux"
    "0hhrxzqv8j48hnas39nq130rj0726vgrf9y35rkm270110759hvr"
    "ghgrab-linux"))

(define-public overskride
  (binary-package "overskride" "0.6.6"
    "https://github.com/kaii-lb/overskride/releases/download/v0.6.6/overskride.tar.xz"
    "0ba91q03g8hasdclv5cw7f09zckzlxykd8s7lm9dr3jpdw9vi1if"
    "overskride"))

(define-public strace-tui
  (binary-package "strace-tui" "1.0.1"
    "https://github.com/Rodrigodd/strace-tui/releases/download/v1.0.1/strace-tui-x86_64-unknown-linux-gnu.tar.gz"
    "0b544w7py8r8b1k8368rpzhc1cc4y9x2yac4fnkmw770l0vrwmxp"
    "strace-tui"))

(define-public tdl
  (binary-package "tdl" "0.20.2"
    "https://github.com/iyear/tdl/releases/download/v0.20.2/tdl_Linux_64bit.tar.gz"
    "0d1b3v8cgh13ibja3qw0233hx1a3n2nasxrzhnxy92hqi9dgyas6"
    "tdl"))

(define-public resterm
  (binary-package "resterm" "0.39.3"
    "https://github.com/unkn0wn-root/resterm/releases/download/v0.39.3/resterm_Linux_x86_64"
    "0d0k00s4a9az9sccd99j9mizwjcmjqzm8mqlkjrq061vdl255y3b"
    "resterm"))

(define-public throne
  (binary-package "throne" "1.1.2"
    "https://github.com/throneproj/throne/releases/download/1.1.2/Throne-1.1.2-linux-amd64.zip"
    "00vnyj0hdihxwv6m5kmw83z4aqi098pbzwbknja2giwg5k4fb00r"
     "throne"))

;; ====== BATCH 3 ======
(define-public oyo
  (binary-package "oyo" "0.1.30"
    "https://github.com/ahkohd/oyo/releases/download/v0.1.30/oy-x86_64-unknown-linux-gnu.tar.gz"
    "0jk78hpafjjw7sr7vzjd241ld9ziwvlkg52z10y7v0891k38d8d0"
    "oy"))

(define-public protonup-rs
  (binary-package "protonup-rs" "0.12.1"
    "https://github.com/auyer/Protonup-rs/releases/download/v0.12.1/protonup-rs-linux-amd64.tar.gz"
    "09byjpfz6xyw61xzxhnrn57hs911m24m89lj2w0w0fp19zsla68k"
    "protonup-rs"))

;; ====== BATCH 4 — source → binary ! ======
(define-public hyprscratch
  (binary-package "hyprscratch" "0.6.4"
    "https://github.com/sashetophizika/hyprscratch/releases/download/v0.6.4/hyprscratch"
    "1gjwplf7ija2g2zq1rl5irz11i4a6rli0pm8bppwlcmx1p3hzihb"
    "hyprscratch"))

(define-public systemd-manager-tui
  (binary-package "systemd-manager-tui" "1.2.4"
    "https://github.com/matheus-git/systemd-manager-tui/releases/download/v1.2.4/systemd-manager-tui"
    "1v71g8y88yfd579zmw5rqc0zicrj1llc07z4liajsilp5w8pgab3"
    "systemd-manager-tui"))

(define-public xdg-ninja
  (binary-package "xdg-ninja" "0.2.0.2"
    "https://github.com/b3nj5m1n/xdg-ninja/releases/download/v0.2.0.2/xdgnj"
    "0yz62dmgygnacybkw9llak5fcazj5z5q04bbhfr10vhnljl54l6b"
    "xdgnj"))

;; jdupes — extracted from pkg.tar.xz (Arch package format)
(define-public jdupes
  (binary-package "jdupes" "1.31.1"
    "https://codeberg.org/jbruchon/jdupes/releases/download/v1.31.1/jdupes-1.31.1-linux-x86_64.pkg.tar.xz"
    "0qd5q6ihd1i50l7kaj9bis3hi2vmv1lgs9vwrsavn1k588q5zr9l"
    "jdupes"))

;; OpenSoundMeter — AppImage binary
(define-public opensoundmeter
  (binary-package "opensoundmeter" "1.5.2"
    "https://github.com/psmokotnin/osm/releases/download/v1.5.2/Open_Sound_Meter-v1.5.2-x86_64.AppImage"
    "1iwj9sdx8bb9ajwnvc6g9l8iqdpdcw073ilrdk2108gdiwqihawg"
    "opensoundmeter"))

;; ====== BATCH 5 — CLI tools for parity ======
(define-public gh-cli
  (binary-package "gh" "2.72.0"
    "https://github.com/cli/cli/releases/download/v2.72.0/gh_2.72.0_linux_amd64.tar.gz"
    "0f3zqwab3mplzgxsfx96s67g6n76aijv00hkaccn3kvm21wsklzz"
    "gh"))

(define-public glow-markdown
  (binary-package "glow" "2.1.0"
    "https://github.com/charmbracelet/glow/releases/download/v2.1.0/glow_2.1.0_linux_x86_64.tar.gz"
    "0mjafsfpzfn348a2a2gigyz89d0ax6m7zli887sa1y6qgqf9lklg"
    "glow"))

(define-public lazygit-bin
  (binary-package "lazygit" "0.48.0"
    "https://github.com/jesseduffield/lazygit/releases/download/v0.48.0/lazygit_0.48.0_Linux_x86_64.tar.gz"
    "1msqyn1qd3vh15kh9nzak8k7hn17sm8qzdfp7gg0a2518g3245r9"
    "lazygit"))

(define-public zellij-bin
  (binary-package "zellij" "0.42.0"
    "https://github.com/zellij-org/zellij/releases/download/v0.42.0/zellij-x86_64-unknown-linux-musl.tar.gz"
    "0s16924xx02d788gk5qbh13fw45d8zkmj2wrz5kw4d1ivnqj237b"
    "zellij"))

;; ====== BATCH 6 — full parity push ======)
