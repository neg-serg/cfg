(use-modules (guix packages) (guix download) (guix build-system trivial) (guix licenses) (guix gexp) (gnu packages compression) (gnu packages gcc))

(define-public rust-latest
  (package
    (name "rust-latest")
    (version "1.95.0")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://static.rust-lang.org/dist/rust-" version "-x86_64-unknown-linux-gnu.tar.gz"))
              (sha256 (base32 "0000000000000000000000000000000000000000000000000000"))))
    (build-system trivial-build-system)
    (inputs (list (specification->package "gcc-toolchain") (specification->package "zlib")))
    (arguments
     (list #:modules '((guix build utils))
           #:builder
           #~(begin
               (use-modules (guix build utils) (ice-9 ftw))
               (let* ((out (assoc-ref %outputs "out"))
                      (src (assoc-ref %build-inputs "source"))
                      (gcc-lib (string-append (assoc-ref %build-inputs "gcc-toolchain") "/lib"))
                      (zlib-lib (string-append (assoc-ref %build-inputs "zlib") "/lib"))
                      (rust-dir (string-append out "/rust"))
                      (rust-lib (string-append rust-dir "/lib"))
                      (rust-bin (string-append rust-dir "/bin")))
                 (mkdir-p out)
                 (invoke "tar" "xzf" src "-C" out)
                 ;; Find the extracted directory 
                 (let ((dir (car (scandir out (lambda (f) (not (member f '("." ".."))))))))
                   (rename-file (string-append out "/" dir) rust-dir))
                 ;; Patch all binaries to use Guix interpreter
                 (for-each (lambda (f)
                            (when (and (not (string-contains f ".so"))
                                       (not (string-suffix? ".a" f)))
                              (invoke "patchelf" "--set-interpreter"
                                      "/gnu/store/i57hp47sdyc277d882gvhjl16kvay0w5-glibc-2.41/lib/ld-linux-x86-64.so.2"
                                      f)
                              (invoke "patchelf" "--set-rpath"
                                      (string-append rust-lib ":" gcc-lib ":" zlib-lib)
                                      f)))
                           (find-files rust-bin))
                 ;; Patch all .so files
                 (for-each (lambda (f)
                            (invoke "patchelf" "--set-rpath"
                                    (string-append rust-lib ":" gcc-lib ":" zlib-lib)
                                    f))
                           (find-files rust-lib "\\.so$"))
                 ;; Create symlinks
                 (mkdir-p (string-append out "/bin"))
                 (for-each (lambda (tool)
                            (symlink (string-append rust-bin "/" tool)
                                     (string-append out "/bin/" tool)))
                           '("rustc" "cargo" "rustdoc" "rustfmt" "clippy-driver"))))))
    (home-page "https://rust-lang.org")
    (synopsis "Rust programming language (latest stable)")
    (description "Latest stable Rust toolchain.")
    (license expat)))

rust-latest
