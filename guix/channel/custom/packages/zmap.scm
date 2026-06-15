(define-module (custom packages zmap)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module (guix build-system cmake)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (custom packages judy)
  #:use-module (gnu packages admin)
  #:use-module (gnu packages c)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages flex)
  #:use-module (gnu packages groff)
  #:use-module (gnu packages libunistring)
  #:use-module (gnu packages multiprecision)
  #:use-module (gnu packages networking)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages popt)
  #:use-module (gnu packages web))

(define-public zmap
  (package
    (name "zmap")
    (version "4.4.0")
    (source (origin
              (method git-fetch)
              (uri (git-reference
                    (url "https://github.com/zmap/zmap")
                    (commit (string-append "v" version))))
              (file-name (git-file-name name version))
              (sha256
               (base32 "0036mackh8wvv43wpf216a6k56rpzrrmpkwwkldrgpkq4ykv8a9k"))))
    (build-system cmake-build-system)
    (arguments
     '(#:tests? #f
       #:configure-flags '("-DWITH_AES_HW=ON" "-DENABLE_DEVELOPMENT=OFF"
                           "-DRESPECT_INSTALL_PREFIX_CONFIG=ON")
       #:phases (modify-phases %standard-phases
                   (add-before 'configure 'fix-cmake-dependency-paths
                    (lambda* (#:key inputs #:allow-other-keys)
                      (let ((judy (assoc-ref inputs "judy"))
                            (byacc (string-append (assoc-ref inputs "byacc")
                                                  "/bin/yacc"))
                            (flex (string-append (assoc-ref inputs "flex")
                                                 "/bin/flex"))
                            (gengetopt (string-append
                                        (assoc-ref inputs "gengetopt")
                                        "/bin/gengetopt")))
                        (substitute* "CMakeLists.txt"
                          (("find_library\\(FOUND_JUDY .*\\)")
                           (string-append
                            "set(FOUND_JUDY \""
                            judy "/lib/libJudy.so\")"))
                          (("find_program\\(FOUND_BYACC .*\\)")
                           (string-append "set(FOUND_BYACC \"" byacc "\")"))
                          (("find_program\\(FOUND_GENGETOPT .*\\)")
                           (string-append
                            "set(FOUND_GENGETOPT \"" gengetopt "\")"))
                          (("find_program\\(FOUND_FLEX .*\\)")
                           (string-append "set(FOUND_FLEX \"" flex "\")"))
                          (("find_library\\(FOUND_GMP .*\\)")
                           "set(FOUND_GMP \"gmp\")")
                          (("find_library\\(FOUND_PCAP .*\\)")
                           "set(FOUND_PCAP \"pcap\")")
                          (("find_library\\(FOUND_JSON .*\\)")
                           "set(FOUND_JSON \"json-c\")"))
                        (substitute* "src/CMakeLists.txt"
                          (("COMMAND byacc -d")
                           (string-append "COMMAND " byacc " -d")))
                        #t))))))
    (native-inputs (list pkg-config byacc flex gengetopt groff))
    (inputs (list gmp json-c judy libpcap libunistring zlib))
    (home-page "https://zmap.io/")
    (synopsis "Fast single-packet network scanner")
    (description "ZMap is a fast network scanner designed for
Internet-wide network surveys.  On a typical desktop computer with a
gigabit Ethernet connection, ZMap is capable of scanning the entire
public IPv4 address space in under 45 minutes.")
    (license license:asl2.0)))

zmap
