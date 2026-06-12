(define-module (custom packages ollama)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages elf)
  #:use-module (gnu packages gcc)
  #:use-module (gnu packages base))

(define-public ollama
  (package
    (name "ollama")
    (version "0.24.0")
    (source
      (origin
        (method url-fetch)
        (uri (string-append
               "https://github.com/ollama/ollama/releases/download/v"
               "0.24.0" "/ollama-linux-amd64.tar.zst"))
        (sha256
          (base32
            "1nywgijy2limpclhjxl29vhndg9dc5l8ipqr8wxhsvm0dgbgii8m"))))
    (build-system gnu-build-system)
    (native-inputs (list patchelf zstd tar))
    (inputs (list `(,gcc "lib")))
    (arguments
     '(#:tests? #f
       #:strip-binaries? #f
       #:validate-runpath? #f
       #:phases (modify-phases %standard-phases
      (replace 'unpack
            (lambda* (#:key source #:allow-other-keys)
              (let* ((zstd-bin (string-append (assoc-ref %build-inputs "zstd") "/bin/zstd"))
                     (tar-bin  (string-append (assoc-ref %build-inputs "tar") "/bin/tar"))
                      (tmp-dir  "/tmp/ollama-unpack")
                      (tmp-tar  (string-append tmp-dir "/ollama.tar")))
                (mkdir-p tmp-dir)
                (invoke zstd-bin "-d" source "-o" tmp-tar)
                (invoke tar-bin "xf" tmp-tar)
                #t)))
         (delete 'configure)
         (delete 'check)
         (delete 'build)
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
                    (let* ((out     (assoc-ref outputs "out"))
                     (bin     (string-append out "/bin"))
                     (glibc   (assoc-ref %build-inputs "libc"))
                     (interp  (string-append glibc "/lib/ld-linux-x86-64.so.2"))
                     (gcc-lib (string-append (assoc-ref %build-inputs "gcc") "/lib"))
                     (pe      (string-append (assoc-ref %build-inputs "patchelf")
                                             "/bin/patchelf")))
                (mkdir-p bin)
                (if (file-exists? "bin/ollama")
                   (begin
                     (install-file "bin/ollama" bin)
                      (invoke pe "--set-interpreter" interp
                              (string-append bin "/ollama"))
                      (invoke pe "--add-rpath" gcc-lib
                              (string-append bin "/ollama")))
                    (if (file-exists? "ollama")
                        (begin
                          (install-file "ollama" bin)
                          (invoke pe "--set-interpreter" interp
                                  (string-append bin "/ollama"))
                          (invoke pe "--add-rpath" gcc-lib
                                  (string-append bin "/ollama")))
                       (format #t "ERROR: ollama not found~%")))
               #t))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://ollama.ai")
    (synopsis "Local LLM runner")
    (description "Run large language models locally.")
    (license expat))) ; MIT ~= expat in Guix

ollama
