(define-module (custom packages richcolors)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses)
  #:use-module (gnu packages python)
  #:use-module (gnu packages python-xyz))

(define-public richcolors
  (package
    (name "richcolors")
    (version "0.0.0")
    (source (origin
              (method url-fetch)
              (uri "https://raw.githubusercontent.com/s-atrn/richcolors/main/richcolors")
              (sha256 (base32 "128prpqdfahgn02xrxcznq6kc8mgwyk8nwfy8n3nim8w8f4b9y11"))))
    (build-system gnu-build-system)
    (inputs (list python-pillow python))
    (arguments
     '(#:tests? #f #:strip-binaries? #f #:validate-runpath? #f
       #:phases (modify-phases %standard-phases
                  (delete 'bootstrap) (delete 'configure) (delete 'check)
                  (delete 'build) (delete 'patch-usr-bin-file)
                  (delete 'patch-generated-file-shebangs)
                  (replace 'install
                    (lambda* (#:key inputs outputs #:allow-other-keys)
                      (let* ((out (assoc-ref outputs "out"))
                             (bin (string-append out "/bin"))
                             (script (car (find-files "." "^richcolors$")))
                             (py (string-append (assoc-ref inputs "python") "/bin/python3"))
                             (pil (string-append (assoc-ref inputs "python-pillow")
                                                 "/lib/python3.11/site-packages")))
                        (mkdir-p bin)
                        (copy-file script (string-append bin "/.richcolors-real"))
                        (chmod (string-append bin "/.richcolors-real") #o555)
                        (call-with-output-file (string-append bin "/richcolors")
                          (lambda (p)
                            (format p "#!~a~%import sys;sys.path.insert(0,~s);exec(open(~s).read())~%"
                                    py pil (string-append bin "/.richcolors-real"))))
                        (chmod (string-append bin "/richcolors") #o555))
                      #t)))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/s-atrn/richcolors")
    (synopsis "Color swatch generator")
    (description "Generate color swatches from hex codes.")
    (license expat)))

richcolors
