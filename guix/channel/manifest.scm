;; Manifest for installing all custom channel packages at once.
;; Usage: guix package -L /home/neg/cfg-channel -m /home/neg/cfg-channel/manifest.scm

(use-modules (custom packages all)
             (guix profiles))

(packages->manifest all-custom-packages)
