(define-module (custom packages sc3-plugins)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages compression))

(define-public sc3-plugins
  (package
    (name "sc3-plugins")
    (version "3.14.0")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://github.com/supercollider/sc3-plugins/releases/download/Version-"
                                  version "/sc3-plugins-" version "-Linux-x64-24.04.zip"))
              (sha256 (base32 "0vizqw6gjia6sr97418pi6yk0ca5h2bbxpr7zy50qhw92njx1w5x"))))
    (build-system gnu-build-system)
    (native-inputs (list unzip))
    (arguments
     '(#:tests? #f #:strip-binaries? #f #:validate-runpath? #f
       #:phases (modify-phases %standard-phases
                  (replace 'unpack
                    (lambda* (#:key source #:allow-other-keys)
                      (invoke "unzip" source)
                      #t))
                  (delete 'bootstrap) (delete 'configure)
                  (delete 'check) (delete 'build)
                  (delete 'patch-usr-bin-file)
                  (delete 'patch-source-shebangs)
                  (delete 'patch-generated-file-shebangs)
                  (replace 'install
                    (lambda* (#:key outputs #:allow-other-keys)
                      (let ((out (assoc-ref outputs "out"))
                            (plugindir "lib/SuperCollider/plugins"))
                        (mkdir-p (string-append out "/" plugindir))
                        (for-each (lambda (f)
                                    (copy-file f (string-append out "/" plugindir "/" (basename f))))
                                  (find-files plugindir ".so"))
                        #t))))))
    (home-page "https://github.com/supercollider/sc3-plugins")
    (synopsis "Community plugins for SuperCollider")
    (description "sc3-plugins provides additional UGens for SuperCollider.")
    (license license:gpl3+)))

sc3-plugins
