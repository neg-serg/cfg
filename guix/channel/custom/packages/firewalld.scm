(define-module (custom packages firewalld)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module (guix build-system gnu)
  #:use-module (guix licenses)
  #:use-module (gnu packages autotools)
  #:use-module (gnu packages docbook)
  #:use-module (gnu packages gettext)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages python)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages glib)
  #:use-module (gnu packages xml)
  #:use-module (gnu packages gnome))

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
    (native-inputs (list autoconf
                         automake
                         libtool
                         gettext-minimal
                         intltool
                         pkg-config
                         python
                         glib
                         `(,glib "bin")
                         docbook-xsl
                         docbook-xml
                         libxslt
                         libxml2))
    (inputs (list iptables
                  nftables
                  ipset
                  ebtables))
    (arguments
     (list #:tests? #f
           #:configure-flags
           #~(list (string-append "--with-iptables=" #$iptables "/sbin/iptables")
                   (string-append "--with-ip6tables=" #$iptables "/sbin/ip6tables"))
           #:phases
           #~(modify-phases %standard-phases
               (add-before 'bootstrap 'patch-configure-ac
                 (lambda _
                   (substitute* "configure.ac"
                     (("JH_CHECK_XML_CATALOG.*manpages.*")
                      "JH_CHECK_XML_CATALOG([http://docbook.sourceforge.net/release/xsl/current/manpages/docbook.xsl], [DocBook XSL Stylesheets], [], [AC_MSG_WARN([DocBook XSL not found, skipping man pages])])"))))
               (add-before 'configure 'set-xml-catalog
                 (lambda _
                   (use-modules (guix build utils))
                   (setenv "XML_CATALOG_FILES"
                           (string-join
                            (append (find-files #$docbook-xsl "^catalog\\.xml$")
                                    (find-files #$docbook-xml "^catalog\\.xml$"))
                            " "))))
               (add-before 'configure 'bootstrap
                 (lambda _
                   (invoke "autoreconf" "-vfi"))))))
    (home-page "https://firewalld.org")
    (synopsis "Dynamic firewall manager with D-Bus interface")
    (description "Firewalld provides a dynamically managed firewall with
support for network/firewall zones to define the trust level of network
connections or interfaces.  It supports IPv4, IPv6, Ethernet bridges,
and IP sets.")
    (license gpl2+)))

firewalld
