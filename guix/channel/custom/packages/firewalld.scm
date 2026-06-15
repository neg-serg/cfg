(define-module (custom packages firewalld)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages python)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages glib))

(define-public firewalld
  (package
    (name "firewalld")
    (version "2.4.1")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://github.com/firewalld/firewalld/"
                                  "archive/v" version ".tar.gz"))
              (sha256 (base32 "12g1lzlcxx2akyfli5cjgmszsr2vh1jmm41y6mda0h8rfi1h193h"))))
    (build-system gnu-build-system)
    (native-inputs (list pkg-config
                         python
                         glib))
    (inputs (list iptables
                  nftables
                  ipset
                  ebtables))
    (arguments
     '(#:tests? #f
       #:configure-flags
       (list "--with-systemd=no"
             "--with-nftables=/run/current-system/profile/sbin/nft"
             "--with-iptables=/run/current-system/profile/sbin/iptables"
             "--with-ip6tables=/run/current-system/profile/sbin/ip6tables")
       #:phases (modify-phases %standard-phases
                  (add-after 'unpack 'patch-shebangs
                    (lambda _
                      (substitute* "configure"
                        (("/usr/bin/env python3")
                         (which "python3"))))))))
    (home-page "https://firewalld.org")
    (synopsis "Dynamic firewall manager with D-Bus interface")
    (description "Firewalld provides a dynamically managed firewall with
support for network/firewall zones to define the trust level of network
connections or interfaces.  It supports IPv4, IPv6, Ethernet bridges,
and IP sets.")
    (license gpl2+)))

firewalld
