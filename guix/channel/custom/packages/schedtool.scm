(define-module (custom packages schedtool)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses))

(define-public schedtool
  (package
    (name "schedtool")
    (version "1.3.0")
    (source (origin
              (method url-fetch)
              (uri (string-append "http://deb.debian.org/debian/pool/main/s/schedtool/"
                                  "schedtool_" version ".orig.tar.gz"))
              (sha256 (base32 "03j5305m7bp3mrncw8gb90gmipnkk72h1cxf5lmwgfgs0plf8a36"))))
    (build-system gnu-build-system)
    (arguments
     '(#:tests? #f
       #:make-flags (list "CFLAGS=-Os -fomit-frame-pointer -s -pipe -Wno-int-conversion")
       #:phases (modify-phases %standard-phases
         (delete 'configure)
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (let* ((out (assoc-ref outputs "out"))
                    (bin (string-append out "/bin"))
                    (man (string-append out "/share/man/man8")))
               (mkdir-p bin)
               (mkdir-p man)
               (install-file "schedtool" bin)
               (invoke "gzip" "-9" "schedtool.8")
               (install-file "schedtool.8.gz" man))
             #t)))))
    (home-page "https://packages.debian.org/sid/schedtool")
    (synopsis "Linux process scheduler query and manipulation tool")
    (description "Schedtool can query or alter a process' scheduling policy in Linux.  It supports all scheduling policies including SCHED_BATCH, SCHED_IDLE, SCHED_FIFO, SCHED_RR, SCHED_ISO, and SCHED_NORMAL with real-time priority, CPU affinity, and nice levels.")
    (license gpl2+)))

schedtool
