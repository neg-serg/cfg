(define-module (custom packages spdlog-1_17)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module (guix build-system cmake)
  #:use-module (guix licenses)
  #:use-module (gnu packages check)
  #:use-module (gnu packages pretty-print))

(define-public spdlog-1.17
  (package
    (name "spdlog")
    (version "1.17.0")
    (source (origin
              (method git-fetch)
              (uri (git-reference
                    (url "https://github.com/gabime/spdlog")
                    (commit (string-append "v" version))))
              (file-name (git-file-name "spdlog" version))
              (sha256
               (base32
                "0dhvr6dqjddrwc7af6x1j6kf9x5z1gnfy8isk03dqp0ic51f3gbc"))))
    (build-system cmake-build-system)
    (inputs (list fmt-12 catch2))
    (arguments
     `(#:tests? #f
       #:configure-flags '("-DSPDLOG_BUILD_SHARED=ON"
                           "-DSPDLOG_FMT_EXTERNAL=ON"
                           "-DSPDLOG_BUILD_EXAMPLE=OFF"
                           "-DSPDLOG_BUILD_TESTS=OFF")))
    (home-page "https://github.com/gabime/spdlog")
    (synopsis "Fast C++ logging library")
    (description "Spdlog is a very fast header-only/compiled C++ logging library.")
    (license expat)))

spdlog-1.17
