(define-module (custom packages rsmetrx)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system cargo)
  #:use-module (guix licenses))

(define-public rsmetrx
  (package
    (name "rsmetrx")
    (version "0.1.0")
    (source (origin
              (method url-fetch)
              (uri "https://github.com/neg-serg/rsmetrx/archive/refs/heads/main.tar.gz")
              (sha256 (base32 "0km2zqhr1dxqpw58naavj6d3ax28wcz5b4prm33vms85vbq6yf61"))))
    (build-system cargo-build-system)
    (arguments
     `(#:tests? #f
       #:phases (modify-phases %standard-phases
         (delete 'check-for-pregenerated-files))
       #:cargo-inputs (             ("aho-corasick" ,(crate-source "aho-corasick" "1.1.3" "05mrpkvdgp5d20y2p989f187ry9diliijgwrs254fs9s1m1x6q4f"))
             ("itoa" ,(crate-source "itoa" "1.0.15" "0b4fj9kz54dr3wam0vprjwgygvycyw8r0qwg7vp19ly8b2w16psa"))
             ("memchr" ,(crate-source "memchr" "2.7.5" "1h2bh2jajkizz04fh047lpid5wgw2cr9igpkdhl3ibzscpd858ij"))
             ("proc-macro2" ,(crate-source "proc-macro2" "1.0.95" "0y7pwxv6sh4fgg6s715ygk1i7g3w02c0ljgcsfm046isibkfbcq2"))
             ("quote" ,(crate-source "quote" "1.0.40" "1394cxjg6nwld82pzp2d4fp6pmaz32gai1zh9z5hvh0dawww118q"))
             ("regex" ,(crate-source "regex" "1.11.1" "148i41mzbx8bmq32hsj1q4karkzzx5m60qza6gdw4pdc9qdyyi5m"))
             ("regex-automata" ,(crate-source "regex-automata" "0.4.9" "02092l8zfh3vkmk47yjc8d631zhhcd49ck2zr133prvd3z38v7l0"))
             ("regex-syntax" ,(crate-source "regex-syntax" "0.8.5" "0p41p3hj9ww7blnbwbj9h7rwxzxg0c1hvrdycgys8rxyhqqw859b"))
             ("ryu" ,(crate-source "ryu" "1.0.20" "07s855l8sb333h6bpn24pka5sp7hjk2w667xy6a0khkf6sqv5lr8"))
             ("serde" ,(crate-source "serde" "1.0.219" "1dl6nyxnsi82a197sd752128a4avm6mxnscywas1jq30srp2q3jz"))
             ("serde_derive" ,(crate-source "serde_derive" "1.0.219" "001azhjmj7ya52pmfiw4ppxm16nd44y15j2pf5gkcwrcgz7pc0jv"))
             ("serde_json" ,(crate-source "serde_json" "1.0.142" "19y5mz1npafnd6vlaiv41ns3pb0pv3q9nirdy3bcn3b0havys3q3"))
             ("syn" ,(crate-source "syn" "2.0.104" "0h2s8cxh5dsh9h41dxnlzpifqqn59cqgm0kljawws61ljq2zgdhp"))
             ("unicode-ident" ,(crate-source "unicode-ident" "1.0.18" "04k5r6sijkafzljykdq26mhjpmhdx4jwzvn1lh90g9ax9903jpss"))
       )))
    (home-page "https://github.com/neg-serg/rsmetrx")
    (synopsis "Metrics collection tool")
    (description "Rust metrics collection tool.")
    (license gpl3+)))

rsmetrx
