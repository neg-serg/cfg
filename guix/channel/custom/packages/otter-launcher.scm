(define-module (custom packages otter-launcher)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system cargo)
  #:use-module (guix licenses))

(define rust-aho-corasick-1.1.3
  (crate-source "aho-corasick" "1.1.3"
                "05mrpkvdgp5d20y2p989f187ry9diliijgwrs254fs9s1m1x6q4f"))

(define rust-bitflags-2.11.0
  (crate-source "bitflags" "2.11.0"
                "1bwjibwry5nfwsfm9kjg2dqx5n5nja9xymwbfl6svnn8jsz6ff44"))

(define rust-cfg-if-1.0.4
  (crate-source "cfg-if" "1.0.4"
                "008q28ajc546z5p2hcwdnckmg0hia7rnx52fni04bwqkzyrghc4k"))

(define rust-cfg-aliases-0.2.1
  (crate-source "cfg_aliases" "0.2.1"
                "092pxdc1dbgjb6qvh83gk56rkic2n2ybm4yvy76cgynmzi3zwfk1"))

(define rust-clipboard-win-5.4.0
  (crate-source "clipboard-win" "5.4.0"
                "14n87fc0vzbd0wdhqzvcs1lqgafsncplzcanhpik93xhhalfgvqm"))

(define rust-endian-type-0.2.0
  (crate-source "endian-type" "0.2.0"
                "1wk235wxf0kqwlbjp3racbl55jwzmh52fg8cbjf1lr93vbdhm6w6"))

(define rust-equivalent-1.0.2
  (crate-source "equivalent" "1.0.2"
                "03swzqznragy8n0x31lqc78g2af054jwivp7lkrbrc0khz74lyl7"))

(define rust-errno-0.3.10
  (crate-source "errno" "0.3.10"
                "0pgblicz1kjz9wa9m0sghkhh2zw1fhq1mxzj7ndjm746kg5m5n1k"))

(define rust-error-code-3.3.1
  (crate-source "error-code" "3.3.1"
                "0bx9hw3pahzqym8jvb0ln4qsabnysgn98mikyh2afhk9rif31nd5"))

(define rust-hashbrown-0.16.1
  (crate-source "hashbrown" "0.16.1"
                "004i3njw38ji3bzdp9z178ba9x3k0c1pgy8x69pj7yfppv4iq7c4"))

(define rust-home-0.5.12
  (crate-source "home" "0.5.12"
                "13bjyzgx6q9srnfvl43dvmhn93qc8mh5w7cylk2g13sj3i3pyqnc"))

(define rust-hostname-0.4.2
  (crate-source "hostname" "0.4.2"
                "1g8cfg0a1v8y5a0zkncbns8hh24amjgskl39cc583wxfawsslyk1"))

(define rust-indexmap-2.13.0
  (crate-source "indexmap" "2.13.0"
                "05qh5c4h2hrnyypphxpwflk45syqbzvqsvvyxg43mp576w2ff53p"))

(define rust-libc-0.2.183
  (crate-source "libc" "0.2.183"
                "17c9gyia7rrzf9gsssvk3vq9ca2jp6rh32fsw6ciarpn5djlddmm"))

(define rust-linux-raw-sys-0.9.3
  ;; TODO REVIEW: Check bundled sources.
  (crate-source "linux-raw-sys" "0.9.3"
                "04zl7j4k1kgbn7rrl3i7yszaglgxp0c8dbwx8f1cabnjjwhb2zgy"))

(define rust-log-0.4.29
  (crate-source "log" "0.4.29"
                "15q8j9c8g5zpkcw0hnd6cf2z7fxqnvsjh3rw5mv5q10r83i34l2y"))

(define rust-memchr-2.8.0
  (crate-source "memchr" "2.8.0"
                "0y9zzxcqxvdqg6wyag7vc3h0blhdn7hkq164bxyx2vph8zs5ijpq"))

(define rust-nibble-vec-0.1.0
  (crate-source "nibble_vec" "0.1.0"
                "0hsdp3s724s30hkqz74ky6sqnadhp2xwcj1n1hzy4vzkz4yxi9bp"))

(define rust-nix-0.31.2
  (crate-source "nix" "0.31.2"
                "1lzmcqcnb9z8l4aq5ympx71bcwc0y5yf7d8jv6hnn7hc682hfvax"))

(define rust-proc-macro2-1.0.106
  (crate-source "proc-macro2" "1.0.106"
                "0d09nczyaj67x4ihqr5p7gxbkz38gxhk4asc0k8q23g9n85hzl4g"))

(define rust-quote-1.0.45
  (crate-source "quote" "1.0.45"
                "095rb5rg7pbnwdp6v8w5jw93wndwyijgci1b5lw8j1h5cscn3wj1"))

(define rust-radix-trie-0.3.0
  (crate-source "radix_trie" "0.3.0"
                "16i8lgwvnhay37hbrf1mg64hba1s4dghnx7gfcmgqdydgl132i1v"))

(define rust-regex-1.11.1
  (crate-source "regex" "1.11.1"
                "148i41mzbx8bmq32hsj1q4karkzzx5m60qza6gdw4pdc9qdyyi5m"))

(define rust-regex-automata-0.4.9
  (crate-source "regex-automata" "0.4.9"
                "02092l8zfh3vkmk47yjc8d631zhhcd49ck2zr133prvd3z38v7l0"))

(define rust-regex-syntax-0.8.5
  (crate-source "regex-syntax" "0.8.5"
                "0p41p3hj9ww7blnbwbj9h7rwxzxg0c1hvrdycgys8rxyhqqw859b"))

(define rust-rustix-1.0.3
  (crate-source "rustix" "1.0.3"
                "15kyccykzx7spxxxx5n39v592bdvzns91cf3xhlqvb4n55aihsp5"))

(define rust-rustyline-18.0.0
  (crate-source "rustyline" "18.0.0"
                "186lghl9lw9smn7sqx3bhkb8cvzmyviixwn7vlwm3cjiycjhp6aa"))

(define rust-rustyline-derive-0.12.0
  (crate-source "rustyline-derive" "0.12.0"
                "03sv43izpsgvkp8j3rmd6pc8x6c0gz8dgs0m8imf3i532xs5irb4"))

(define rust-serde-1.0.228
  (crate-source "serde" "1.0.228"
                "17mf4hhjxv5m90g42wmlbc61hdhlm6j9hwfkpcnd72rpgzm993ls"))

(define rust-serde-core-1.0.228
  (crate-source "serde_core" "1.0.228"
                "1bb7id2xwx8izq50098s5j2sqrrvk31jbbrjqygyan6ask3qbls1"))

(define rust-serde-derive-1.0.228
  (crate-source "serde_derive" "1.0.228"
                "0y8xm7fvmr2kjcd029g9fijpndh8csv5m20g4bd76w8qschg4h6m"))

(define rust-serde-spanned-1.1.0
  (crate-source "serde_spanned" "1.1.0"
                "166ds31qqkc70k28pspiknnpkvqaxdln6aq3n4mqhkqd0r8w6sl7"))

(define rust-smallvec-1.14.0
  (crate-source "smallvec" "1.14.0"
                "1z8wpr53x6jisklqhkkvkgyi8s5cn69h2d2alhqfxahzxwiq7kvz"))

(define rust-syn-2.0.117
  (crate-source "syn" "2.0.117"
                "16cv7c0wbn8amxc54n4w15kxlx5ypdmla8s0gxr2l7bv7s0bhrg6"))

(define rust-terminal-size-0.4.3
  (crate-source "terminal_size" "0.4.3"
                "1l7cicmz49c0cyskfp5a389rsai649xi7y032v73475ikjbwpf30"))

(define rust-toml-1.1.0+spec-1.1.0
  (crate-source "toml" "1.1.0+spec-1.1.0"
                "1k4z4fmq5bnzrdwkgr6477vhlck12qly7wwlpbs2idsfbsh5q6gq"))

(define rust-toml-datetime-1.1.0+spec-1.1.0
  (crate-source "toml_datetime" "1.1.0+spec-1.1.0"
                "13qrb6d5cnsq5gm7b7v081vhddhzx2km51safy1ss0vy65y1l9cp"))

(define rust-toml-parser-1.1.0+spec-1.1.0
  (crate-source "toml_parser" "1.1.0+spec-1.1.0"
                "04a0pfm9hp18mhk2lrm85fkia5ya2f5grf7r9nq7wq33wcgg2d13"))

(define rust-toml-writer-1.1.0+spec-1.1.0
  (crate-source "toml_writer" "1.1.0+spec-1.1.0"
                "1vgq92b1j95n3jmk44mbdl2y8wy0l2xynmqywkrzl4k307kav0nj"))

(define rust-unicode-ident-1.0.18
  (crate-source "unicode-ident" "1.0.18"
                "04k5r6sijkafzljykdq26mhjpmhdx4jwzvn1lh90g9ax9903jpss"))

(define rust-unicode-segmentation-1.12.0
  (crate-source "unicode-segmentation" "1.12.0"
                "14qla2jfx74yyb9ds3d2mpwpa4l4lzb9z57c6d2ba511458z5k7n"))

(define rust-unicode-width-0.2.2
  (crate-source "unicode-width" "0.2.2"
                "0m7jjzlcccw716dy9423xxh0clys8pfpllc5smvfxrzdf66h9b5l"))

(define rust-urlencoding-2.1.3
  (crate-source "urlencoding" "2.1.3"
                "1nj99jp37k47n0hvaz5fvz7z6jd0sb4ppvfy3nphr1zbnyixpy6s"))

(define rust-utf8parse-0.2.2
  (crate-source "utf8parse" "0.2.2"
                "088807qwjq46azicqwbhlmzwrbkz7l4hpw43sdkdyyk524vdxaq6"))

(define rust-windows-link-0.1.3
  (crate-source "windows-link" "0.1.3"
                "12kr1p46dbhpijr4zbwr2spfgq8i8c5x55mvvfmyl96m01cx4sjy"))

(define rust-windows-link-0.2.1
  (crate-source "windows-link" "0.2.1"
                "1rag186yfr3xx7piv5rg8b6im2dwcf8zldiflvb22xbzwli5507h"))

(define rust-windows-sys-0.59.0
  ;; TODO REVIEW: Check bundled sources.
  (crate-source "windows-sys" "0.59.0"
                "0fw5672ziw8b3zpmnbp9pdv1famk74f1l9fcbc3zsrzdg56vqf0y"))

(define rust-windows-sys-0.60.2
  ;; TODO REVIEW: Check bundled sources.
  (crate-source "windows-sys" "0.60.2"
                "1jrbc615ihqnhjhxplr2kw7rasrskv9wj3lr80hgfd42sbj01xgj"))

(define rust-windows-sys-0.61.2
  ;; TODO REVIEW: Check bundled sources.
  (crate-source "windows-sys" "0.61.2"
                "1z7k3y9b6b5h52kid57lvmvm05362zv1v8w0gc7xyv5xphlp44xf"))

(define rust-windows-targets-0.52.6
  (crate-source "windows-targets" "0.52.6"
                "0wwrx625nwlfp7k93r2rra568gad1mwd888h1jwnl0vfg5r4ywlv"))

(define rust-windows-targets-0.53.3
  (crate-source "windows-targets" "0.53.3"
                "14fwwm136dhs3i1impqrrip7nvkra3bdxa4nqkblj604qhqn1znm"))

(define rust-windows-aarch64-gnullvm-0.52.6
  (crate-source "windows_aarch64_gnullvm" "0.52.6"
                "1lrcq38cr2arvmz19v32qaggvj8bh1640mdm9c2fr877h0hn591j"))

(define rust-windows-aarch64-gnullvm-0.53.0
  (crate-source "windows_aarch64_gnullvm" "0.53.0"
                "0r77pbpbcf8bq4yfwpz2hpq3vns8m0yacpvs2i5cn6fx1pwxbf46"))

(define rust-windows-aarch64-msvc-0.52.6
  (crate-source "windows_aarch64_msvc" "0.52.6"
                "0sfl0nysnz32yyfh773hpi49b1q700ah6y7sacmjbqjjn5xjmv09"))

(define rust-windows-aarch64-msvc-0.53.0
  (crate-source "windows_aarch64_msvc" "0.53.0"
                "0v766yqw51pzxxwp203yqy39ijgjamp54hhdbsyqq6x1c8gilrf7"))

(define rust-windows-i686-gnu-0.52.6
  (crate-source "windows_i686_gnu" "0.52.6"
                "02zspglbykh1jh9pi7gn8g1f97jh1rrccni9ivmrfbl0mgamm6wf"))

(define rust-windows-i686-gnu-0.53.0
  (crate-source "windows_i686_gnu" "0.53.0"
                "1hvjc8nv95sx5vdd79fivn8bpm7i517dqyf4yvsqgwrmkmjngp61"))

(define rust-windows-i686-gnullvm-0.52.6
  (crate-source "windows_i686_gnullvm" "0.52.6"
                "0rpdx1537mw6slcpqa0rm3qixmsb79nbhqy5fsm3q2q9ik9m5vhf"))

(define rust-windows-i686-gnullvm-0.53.0
  (crate-source "windows_i686_gnullvm" "0.53.0"
                "04df1in2k91qyf1wzizvh560bvyzq20yf68k8xa66vdzxnywrrlw"))

(define rust-windows-i686-msvc-0.52.6
  (crate-source "windows_i686_msvc" "0.52.6"
                "0rkcqmp4zzmfvrrrx01260q3xkpzi6fzi2x2pgdcdry50ny4h294"))

(define rust-windows-i686-msvc-0.53.0
  (crate-source "windows_i686_msvc" "0.53.0"
                "0pcvb25fkvqnp91z25qr5x61wyya12lx8p7nsa137cbb82ayw7sq"))

(define rust-windows-x86-64-gnu-0.52.6
  (crate-source "windows_x86_64_gnu" "0.52.6"
                "0y0sifqcb56a56mvn7xjgs8g43p33mfqkd8wj1yhrgxzma05qyhl"))

(define rust-windows-x86-64-gnu-0.53.0
  (crate-source "windows_x86_64_gnu" "0.53.0"
                "1flh84xkssn1n6m1riddipydcksp2pdl45vdf70jygx3ksnbam9f"))

(define rust-windows-x86-64-gnullvm-0.52.6
  (crate-source "windows_x86_64_gnullvm" "0.52.6"
                "03gda7zjx1qh8k9nnlgb7m3w3s1xkysg55hkd1wjch8pqhyv5m94"))

(define rust-windows-x86-64-gnullvm-0.53.0
  (crate-source "windows_x86_64_gnullvm" "0.53.0"
                "0mvc8119xpbi3q2m6mrjcdzl6afx4wffacp13v76g4jrs1fh6vha"))

(define rust-windows-x86-64-msvc-0.52.6
  (crate-source "windows_x86_64_msvc" "0.52.6"
                "1v7rb5cibyzx8vak29pdrk8nx9hycsjs4w0jgms08qk49jl6v7sq"))

(define rust-windows-x86-64-msvc-0.53.0
  (crate-source "windows_x86_64_msvc" "0.53.0"
                "11h4i28hq0zlnjcaqi2xdxr7ibnpa8djfggch9rki1zzb8qi8517"))

(define rust-winnow-1.0.0
  (crate-source "winnow" "1.0.0"
                "1n67gx8mg2b6r2z54zwbrb6qsfbdsar1lvafsfaajr3jcvj8h3m9"))



(define-public otter-launcher
  (package
    (name "otter-launcher")
    (version "0.7.4")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://github.com/kuokuo123/otter-launcher/archive/refs/tags/v" version ".tar.gz"))
              (sha256 (base32 "14y867amwjkd5p7ndjzkrazg9sqq62rqrpk1g638q55mva1qiljx"))))
    (build-system cargo-build-system)
    (arguments
      `(#:tests? #f
        #:cargo-inputs (("aho-corasick" ,rust-aho-corasick-1.1.3)
             ("bitflags" ,rust-bitflags-2.11.0)
             ("cfg-if" ,rust-cfg-if-1.0.4)
             ("cfg-aliases" ,rust-cfg-aliases-0.2.1)
             ("clipboard-win" ,rust-clipboard-win-5.4.0)
             ("endian-type" ,rust-endian-type-0.2.0)
             ("equivalent" ,rust-equivalent-1.0.2)
             ("errno" ,rust-errno-0.3.10)
             ("error-code" ,rust-error-code-3.3.1)
             ("hashbrown" ,rust-hashbrown-0.16.1)
             ("home" ,rust-home-0.5.12)
             ("hostname" ,rust-hostname-0.4.2)
             ("indexmap" ,rust-indexmap-2.13.0)
             ("libc" ,rust-libc-0.2.183)
             ("linux-raw-sys" ,rust-linux-raw-sys-0.9.3)
             ("log" ,rust-log-0.4.29)
             ("memchr" ,rust-memchr-2.8.0)
             ("nibble-vec" ,rust-nibble-vec-0.1.0)
             ("nix" ,rust-nix-0.31.2)
             ("proc-macro2" ,rust-proc-macro2-1.0.106)
             ("quote" ,rust-quote-1.0.45)
             ("radix-trie" ,rust-radix-trie-0.3.0)
             ("regex" ,rust-regex-1.11.1)
             ("regex-automata" ,rust-regex-automata-0.4.9)
             ("regex-syntax" ,rust-regex-syntax-0.8.5)
             ("rustix" ,rust-rustix-1.0.3)
             ("rustyline" ,rust-rustyline-18.0.0)
             ("rustyline-derive" ,rust-rustyline-derive-0.12.0)
             ("serde" ,rust-serde-1.0.228)
             ("serde-core" ,rust-serde-core-1.0.228)
             ("serde-derive" ,rust-serde-derive-1.0.228)
             ("serde-spanned" ,rust-serde-spanned-1.1.0)
             ("smallvec" ,rust-smallvec-1.14.0)
             ("syn" ,rust-syn-2.0.117)
             ("terminal-size" ,rust-terminal-size-0.4.3)
             ("toml" ,rust-toml-1.1.0+spec-1.1.0)
             ("toml-datetime" ,rust-toml-datetime-1.1.0+spec-1.1.0)
             ("toml-parser" ,rust-toml-parser-1.1.0+spec-1.1.0)
             ("toml-writer" ,rust-toml-writer-1.1.0+spec-1.1.0)
             ("unicode-ident" ,rust-unicode-ident-1.0.18)
             ("unicode-segmentation" ,rust-unicode-segmentation-1.12.0)
             ("unicode-width" ,rust-unicode-width-0.2.2)
             ("urlencoding" ,rust-urlencoding-2.1.3)
             ("utf8parse" ,rust-utf8parse-0.2.2)
             ("windows-link" ,rust-windows-link-0.1.3)
             ("windows-link" ,rust-windows-link-0.2.1)
             ("windows-sys" ,rust-windows-sys-0.59.0)
             ("windows-sys" ,rust-windows-sys-0.60.2)
             ("windows-sys" ,rust-windows-sys-0.61.2)
             ("windows-targets" ,rust-windows-targets-0.52.6)
             ("windows-targets" ,rust-windows-targets-0.53.3)
             ("windows-aarch64-gnullvm" ,rust-windows-aarch64-gnullvm-0.52.6)
             ("windows-aarch64-gnullvm" ,rust-windows-aarch64-gnullvm-0.53.0)
             ("windows-aarch64-msvc" ,rust-windows-aarch64-msvc-0.52.6)
             ("windows-aarch64-msvc" ,rust-windows-aarch64-msvc-0.53.0)
             ("windows-i686-gnu" ,rust-windows-i686-gnu-0.52.6)
             ("windows-i686-gnu" ,rust-windows-i686-gnu-0.53.0)
             ("windows-i686-gnullvm" ,rust-windows-i686-gnullvm-0.52.6)
             ("windows-i686-gnullvm" ,rust-windows-i686-gnullvm-0.53.0)
             ("windows-i686-msvc" ,rust-windows-i686-msvc-0.52.6)
             ("windows-i686-msvc" ,rust-windows-i686-msvc-0.53.0)
             ("windows-x86" ,rust-windows-x86-64-gnu-0.52.6)
             ("windows-x86" ,rust-windows-x86-64-gnu-0.53.0)
             ("windows-x86" ,rust-windows-x86-64-gnullvm-0.52.6)
             ("windows-x86" ,rust-windows-x86-64-gnullvm-0.53.0)
             ("windows-x86" ,rust-windows-x86-64-msvc-0.52.6)
             ("windows-x86" ,rust-windows-x86-64-msvc-0.53.0)
               ("winnow" ,rust-winnow-1.0.0)
       )))
    (home-page "https://github.com/kuokuo123/otter-launcher")
    (synopsis "Application launcher")
    (description "Otter Launcher.")
    (license gpl3+)))

otter-launcher
