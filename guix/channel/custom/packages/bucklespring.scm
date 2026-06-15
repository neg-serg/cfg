(define-module (custom packages bucklespring)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses)
  #:use-module (gnu packages audio)
  #:use-module (gnu packages xorg)
  #:use-module (gnu packages pulseaudio)
  #:use-module (gnu packages mp3)
  #:use-module (gnu packages xiph)
  #:use-module (gnu packages pkg-config))

(define-public bucklespring
  (package
    (name "bucklespring")
    (version "1.5.1")
    (source (origin
              (method git-fetch)
              (uri (git-reference
                    (url "https://github.com/zevv/bucklespring")
                    (commit (string-append "v" version))))
              (file-name (git-file-name name version))
              (sha256 (base32 "0prhqibivxzmz90k79zpwx3c97h8wa61rk5ihi9a5651mnc46mna"))))
    (build-system gnu-build-system)
    (native-inputs (list pkg-config))
    (inputs (list openal alure libxtst libx11
                  libsndfile libvorbis flac mpg123))
    (arguments
     '(#:tests? #f
       #:phases (modify-phases %standard-phases
         (delete 'configure)
         (replace 'build
           (lambda _
             (invoke "make" (string-append "CC=gcc"))))
         (replace 'install
           (lambda* (#:key outputs inputs #:allow-other-keys)
             (let* ((out    (assoc-ref outputs "out"))
                    (bin    (string-append out "/bin"))
                    (share  (string-append out "/share/bucklespring"))
                    (wav    (string-append share "/wav"))
                    (libs   (map (lambda (pkg)
                                   (string-append (assoc-ref inputs pkg) "/lib"))
                                 '("libsndfile" "libvorbis" "flac" "mpg123"))))
               (mkdir-p bin)
               (install-file "buckle" (string-append out "/libexec"))
               (copy-recursively "wav" wav)
               (call-with-output-file (string-append bin "/buckle")
                 (lambda (port)
                   (format port "#!~a/bin/sh~%" (assoc-ref inputs "bash"))
                   (format port "export LD_LIBRARY_PATH=~a:$LD_LIBRARY_PATH~%"
                           (string-join libs ":"))
                   (format port "exec ~a/libexec/buckle \"$@\"~%" out)))
               (chmod (string-append bin "/buckle") #o555)
               #t))))))
    (home-page "https://github.com/zevv/bucklespring")
    (synopsis "Nostalgia bucklespring keyboard sound emulator")
    (description "Bucklespring runs as a background process and plays back the
sound of each key pressed and released on your keyboard, just as if you were
using an IBM Model-M buckling spring keyboard.")
    (license gpl2+)))

bucklespring
