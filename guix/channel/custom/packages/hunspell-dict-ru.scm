(define-module (custom packages hunspell-dict-ru)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix build-system trivial)
  #:use-module (guix licenses))

(define-public hunspell-dict-ru
  (let ((dict-tarball (local-file "data/hunspell-ru.tar.gz")))
    (package
      (name "hunspell-dict-ru")
      (version "20210701")
      (source dict-tarball)
      (build-system trivial-build-system)
      (arguments
       `(#:modules ((guix build utils))
         #:builder (begin
                    (use-modules (guix build utils))
                    (let* ((out (assoc-ref %outputs "out"))
                           (dic-dir (string-append out "/share/hunspell")))
                      (mkdir-p dic-dir)
                      (system (string-append "gunzip -c " (assoc-ref %build-inputs "source")
                                             " | (cd " dic-dir " && tar xf -)"))
                      #t))))
      (home-page "https://github.com/wooorm/dictionaries")
      (synopsis "Russian hunspell dictionary")
      (description "Russian dictionary (ru_RU) for Hunspell spell checker.")
      (license gpl3+))))

hunspell-dict-ru
