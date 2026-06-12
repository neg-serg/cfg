(define-module (custom packages amdgpu-switcher)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses))

(define-public amdgpu-vulkan-switcher
  (package
    (name "amdgpu-vulkan-switcher")
    (version "0.1.0")
    (source (origin
              (method url-fetch)
              (uri "https://github.com/CosmicFusion/amdgpu-vulkan-switcher/archive/refs/heads/main.tar.gz")
              (sha256 (base32 "1xdm8l1hdjsnzhk3qjh5q8lfz0m58k58n4pk0skgy0q8448gyf5c"))))
    (build-system gnu-build-system)
    (arguments
     '(#:tests? #f #:strip-binaries? #f #:validate-runpath? #f
       #:phases (modify-phases %standard-phases
         (delete 'configure) (delete 'check) (delete 'build)
          (delete 'bootstrap) (delete 'patch-source-shebangs)
          (delete 'patch-generated-file-shebangs)
          (replace 'install
            (lambda* (#:key outputs #:allow-other-keys)
              (let* ((out (assoc-ref outputs "out"))
                     (bin (string-append out "/bin")))
                (mkdir-p bin)
                (for-each (lambda (f)
                           (let ((src (find-files "." (lambda (p _)
                                          (string= (basename p) f)))))
                             (if (pair? src)
                                 (begin
                                   (copy-file (car src) (string-append bin "/" f))
                                   (chmod (string-append bin "/" f) #o555))
                                 (error "cannot find" f))))
                         '("vk_amdvlk" "vk_legacy" "vk_pro" "vk_radv"))
                #t))))))
    (home-page "https://github.com/CosmicFusion/amdgpu-vulkan-switcher")
    (synopsis "AMD Vulkan driver switcher")
    (description "Switch between AMD Vulkan drivers.")
    (license gpl3+)))

amdgpu-vulkan-switcher
