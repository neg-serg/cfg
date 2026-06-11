;;; custom/packages/binaries.scm — pre-built binary packages (like AUR -bin)
(define-module (custom packages binaries)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system trivial)
  #:use-module (guix licenses)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages base)
  #:use-module (ice-9 match))

;;; Template for binary packages:
;;; 1. Download the release binary
;;; 2. Unpack if needed
;;; 3. Install to /bin

(define (make-binary-package name version url hash arch)
  "Create a package that installs a pre-built binary."
  (package
    (name name)
    (version version)
    (source
      (origin
        (method url-fetch)
        (uri url)
        (sha256 (base32 hash))))
    (build-system trivial-build-system)
    (arguments
     `(#:modules ((guix build utils))
       #:builder
       (begin
         (use-modules (guix build utils))
         (let* ((source (assoc-ref %build-inputs "source"))
                (out    (assoc-ref %outputs "out"))
                (bin    (string-append out "/bin"))
                (target (string-append bin "/" ,name)))
           (mkdir-p bin)
           (copy-file source target)
           (chmod target #o555)))))
    (home-page "")
    (synopsis (string-append name " — pre-built binary"))
    (description "")
    (license gpl3+)))

;;; Template example — see oports.scm for the real package.
;; (define-public oports
;;   (package
;;     (name "oports")
;;     (version "0.1.0")
;;     (source
;;       (origin
;;         (method git-fetch)
;;         (uri (git-reference
;;               (url "https://github.com/sdushantha/oports")
;;               (commit "master")))
;;         (file-name (git-file-name name version))
;;         (sha256 (base32 "0000000000000000000000000000000000000000000000000000"))))
;;     (build-system trivial-build-system)
;;     (arguments
;;      '(#:modules ((guix build utils))
;;        #:builder
;;        (begin
;;          (use-modules (guix build utils))
;;          (let* ((source (assoc-ref %build-inputs "source"))
;;                 (out    (assoc-ref %outputs "out"))
;;                 (bin    (string-append out "/bin")))
;;            (mkdir-p bin)
;;            (copy-recursively source (string-append out "/share/oports"))
;;            (symlink (string-append out "/share/oports/oports.sh")
;;                     (string-append bin "/oports"))
;;            (chmod (string-append bin "/oports") #o555)))))
;;     (home-page "https://github.com/sdushantha/oports")
;;     (synopsis "Network port scanner")
;;     (description "Simple network port scanner written in bash.")
;;     (license gpl3+)))
