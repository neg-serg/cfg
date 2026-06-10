(define-module (custom packages instagram-cli)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses)
  #:use-module (gnu packages node))

(define-public instagram-cli
  (package
    (name "instagram-cli")
    (version "1.4.2")
    (source (origin
              (method url-fetch)
              (uri "https://registry.npmjs.org/@i7m/instagram-cli/-/instagram-cli-1.4.2.tgz")
              (sha256 (base32 "1chyavnni36ghnjbi4iyx4hfhc8fnmn8pf0sfrz5dmhww7qfmmz3"))))
    (build-system gnu-build-system)
    (native-inputs (list node))
    (arguments
     '(#:tests? #f #:strip-binaries? #f #:validate-runpath? #f
       #:phases (modify-phases %standard-phases
                  (delete 'bootstrap) (delete 'configure) (delete 'check)
                  (delete 'build) (delete 'patch-usr-bin-file)
                  (delete 'patch-source-shebangs)
                  (delete 'patch-generated-file-shebangs)
                  (replace 'install
                    (lambda* (#:key outputs #:allow-other-keys)
                      (let* ((out (assoc-ref outputs "out"))
                             (bin (string-append out "/bin"))
                             (js (car (find-files "." "index\\.js$")))
                             (dir (dirname js)))
                        (mkdir-p bin)
                        ;; Create wrapper script
                        (call-with-output-file (string-append bin "/instagram")
                          (lambda (port)
                            (format port "#!~a/bin/node
process.chdir('~a');
require('./index');~%"
                                    (assoc-ref %build-inputs "node")
                                    dir)))
                        (chmod (string-append bin "/instagram") #o555))
                      #t)))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/supreme-gg-gg/instagram-cli")
    (synopsis "Terminal UI client for Instagram")
    (description "Terminal UI client for Instagram with chat, feed, stories support.")
    (license expat)))

instagram-cli