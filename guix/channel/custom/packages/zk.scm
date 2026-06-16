(define-module (custom packages zk)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module ((guix licenses) #:prefix license:))

(define-public zk
  (package
    (name "zk")
    (version "0.15.5")
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "https://github.com/zk-org/zk/releases/download/v"
             version "/zk-v" version "-linux-amd64.tar.gz"))
       (sha256
        (base32 "1s3hfyq4hy4i8mca0p6gwck6i7js6975sjh5mspcf70s0x3jalpc"))))
    (build-system gnu-build-system)
    (arguments
     '(#:tests? #f
       #:strip-binaries? #f
       #:validate-runpath? #f
       #:phases (modify-phases %standard-phases
                  (delete 'bootstrap)
                  (delete 'configure)
                  (delete 'check)
                  (delete 'build)
                  (delete 'patch-usr-bin-file)
                  (delete 'patch-source-shebangs)
                  (delete 'patch-generated-file-shebangs)
                  (replace 'install
                    (lambda* (#:key outputs #:allow-other-keys)
                      (let ((bin (string-append (assoc-ref outputs "out") "/bin")))
                        (mkdir-p bin)
                        (copy-file "zk" (string-append bin "/zk"))
                        (chmod (string-append bin "/zk") #o555)))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/zk-org/zk")
    (synopsis "Plain text Zettelkasten note-taking assistant")
    (description "zk is a command-line tool for maintaining a plain text
Zettelkasten or personal wiki.  Features include note creation from templates,
advanced search and filtering, LSP integration for editors, interactive fzf
browsing, and support for Wikilinks, hashtags, and YAML frontmatter.")
    (license license:gpl3+)))

zk
