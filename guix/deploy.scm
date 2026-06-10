#!/usr/bin/env -S guile -s
!#
;;; Guix System — Full Deployment (Guile Scheme)
;;; Single command: guile deploy.scm
;;; Does: reconfigure → chezmoi → gopass → tools → services

(use-modules (ice-9 format)
             (ice-9 ftw)
             (ice-9 match)
             (ice-9 popen)
             (ice-9 rdelim)
             (ice-9 regex)
             (ice-9 textual-ports)
             (srfi srfi-1)
             (srfi srfi-13)
             (srfi srfi-26))

(define (dotfile? f) (string-prefix? "." f))
(define home (getenv "HOME"))
(define repo-dir (string-append home "/cfg-channel"))
(define channel-dir (string-append repo-dir "/guix/channel"))
(define profile (string-append home "/.guix-profile"))
(define green  "\x1b[1;32m")
(define yellow "\x1b[1;33m")
(define red    "\x1b[1;31m")
(define bold   "\x1b[1m")
(define nc     "\x1b[0m")
(define total-steps 7)
(define step-n 0)

(define (now)
  (strftime "%H:%M:%S" (localtime (current-time))))

(define (sh/quiet . args)
  "Run command silently, return exit code."
  (let ((cmd (string-join args " ")))
    (system (string-append cmd " >/dev/null 2>&1"))))

(define (sh . args)
  (let ((cmd (string-join args " ")))
    (let ((ret (system (string-append cmd " 2>&1"))))
      (unless (zero? ret)
        (format (current-error-port) "~a  ✗ ~a (exit ~a)~a~%"
                red cmd ret nc)))))

(define (sh/cap . args)
  "Run command, return stdout as string."
  (let* ((cmd (string-join args " "))
         (port (open-input-pipe (string-append cmd " 2>/dev/null")))
         (out (read-string port)))
    (close-pipe port)
    (string-trim-right out #\newline)))

(define (sh/ok? . args)
  "Run command, return #t if exit 0."
  (zero? (system (string-append (string-join args " ") " >/dev/null 2>&1"))))

(define (step-ok msg)
  (format #t "\r  ~a[~a/~a]~a ~a✓ ~a~a (~a)~%"
          bold step-n total-steps nc green msg nc (now)))

(define (step-warn msg)
  (format #t "\r  ~a[~a/~a]~a ~a⚠ ~a~a (~a)~%"
          bold step-n total-steps nc yellow msg nc (now)))

(define (find-sudo)
  (let loop ((paths '("/run/privileged/bin/sudo"
                       "/run/setuid-programs/sudo"
                       "/run/current-system/profile/bin/sudo")))
    (match paths
      (() "sudo")
      ((p . rest) (if (access? p X_OK) p (loop rest))))))

(define sudo (find-sudo))

;; ── Step 0: Bootstrap Key ──
(format #t "~%  ~a══ Bootstrap Key ══~a~%" bold nc)
(format #t "  This key decrypts gopass (VPN, API keys, passwords).~%")
(format #t "  You need the AGE secret key or GPG key from your host.~%")
(format #t "~%")

;; Sync with origin before doing anything
(let ((git-dir (string-append repo-dir "/.git")))
  (when (access? git-dir R_OK)
    (system (string-append "cd " repo-dir
                           " && git fetch origin main 2>/dev/null"
                           " && git reset --hard origin/main 2>/dev/null"))))

(let ((age-key-file (string-append home "/.config/age/key.txt"))
      (env-key (getenv "AGE_SECRET_KEY")))
  (cond
   ((and env-key (not (string-null? env-key)))
    (mkdir-p (dirname age-key-file))
    (with-output-to-file age-key-file (lambda () (display env-key) (newline)))
    (system (string-append "chmod 600 " age-key-file))
    (format #t "  ~a✓~a AGE_SECRET_KEY from environment~%" green nc))
   ((access? age-key-file R_OK)
    (format #t "  ~a✓~a Age key found at ~a~%" green nc age-key-file))
   ((not (isatty? (current-input-port)))
    (format #t "  ~a⚠~a No TTY — skipping AGE key prompt~a~%" yellow nc nc))
   (else
    (format #t "  ~aEnter AGE-SECRET-KEY or GPG key (blank = skip secrets):~a~%" bold nc)
    (display "  > ")
    (let ((key (read-line)))
      (if (string-null? key)
          (format #t "  ~a⚠~a Skipped — gopass won't work~%" yellow nc)
          (begin
            (system (string-append "mkdir -p " home "/.config/age"))
            (with-output-to-file age-key-file (lambda () (display key) (newline)))
            (system (string-append "chmod 600 " age-key-file))
            (format #t "  ~a✓~a Key saved~%" green nc)))))))

(define (mkdir-p dir)
  (system (string-append "mkdir -p " dir)))

(define (dirname path)
  (let ((i (string-rindex path #\/)))
    (if i (substring path 0 i) ".")))

(define (step n title)
  (format #t "~%~a[~a/8]~a ~a~%" green n nc title))

;; ── Step 1: System Reconfigure ──
(step 1 "System reconfigure")
(let ((config (string-append repo-dir "/guix/system-config.scm")))
  (unless (access? config R_OK)
    (format #t "FATAL: system-config.scm not found.~%Clone: git clone https://github.com/neg-serg/cfg.git ~a~%" repo-dir)
    (exit 1))
  (sh sudo "cp" config "/etc/config.scm")
  (sh sudo "guix" "system" "reconfigure" "/etc/config.scm" "-L" channel-dir "--fallback")
  (let* ((gen (sh/cap "guix" "system" "describe"))
         (m (string-match "Generation [0-9]+" gen)))
    (format #t "  => ~a~%" (if m (match:substring m) gen))))

;; ── Step 3: Chezmoi ──
(step 3 "Chezmoi dotfiles")
(let ((chezmoi-dir (string-append home "/.local/share/chezmoi")))
  (unless (access? chezmoi-dir R_OK)
    (or (sh/ok? "git" "clone" "https://github.com/neg-serg/cfg.git" chezmoi-dir)
        (sh/ok? "git" "clone" "git@github.com:neg-serg/cfg.git" chezmoi-dir)))
  ;; Set PASSWORD_STORE_DIR so gopass templates work
  (setenv "PASSWORD_STORE_DIR" (string-append home "/.local/share/pass"))
  (sh "chezmoi" "apply" "--force")
  (let ((managed (sh/cap "chezmoi" "managed")))
    (format #t "  ~a files applied~%"
            (if (string-null? managed) 0
                (length (string-split managed #\newline))))))

;; ── Step 4: Gopass ──
(step 4 "Gopass")
(let ((pass-dir (string-append home "/.local/share/pass")))
  (setenv "PASSWORD_STORE_DIR" pass-dir)
  (if (access? pass-dir R_OK)
      (format #t "  Gopass store exists at ~a~%" pass-dir)
      (if (sh/ok? "timeout" "10" "gopass" "clone")
          (format #t "  Gopass store cloned~%")
          (if (sh/ok? "timeout" "10" "gopass" "init")
              (format #t "  Gopass initialized (empty store)~%")
              (format #t "  ~aGopass init failed~a~%" yellow nc)))))

;; Verify required secrets for xray/proxypilot templates
(format #t "  Checking VPN/proxy secrets...~%")
(for-each
 (lambda (secret)
   (if (sh/ok? "timeout" "5" "gopass" "show" secret)
       (format #t "    ~a: OK~%" secret)
       (format #t "    ~a~a: MISSING~a~%" yellow secret nc)))
 '("proxypilot/api-key" "vpn/xray-address"))

;; ── Step 5: npm/pip Tools ──
(step 5 "Developer tools (npm/pip)")
(for-each (lambda (pkg)
            (when (sh/ok? "guix" "install" pkg)
              (format #t "  ~a: guix~%" pkg)))
          '("python-debugpy" "python-mypy" "python-docutils"))
(sh "bash" "-c" "echo pip packages already installed via Guix step 2.5")
(format #t "  pip tools: done~%")
(sh "npm" "install" "-g" "@anthropic-ai/claude-code" "@openai/codex")
(format #t "  npm tools: done~%")

;; ── Step 6: Default Configs ──
(step 6 "Creating configs")

;; Zsh env
(let ((zsh-dir (string-append home "/.config/zsh")))
  (system (string-append "mkdir -p " zsh-dir))
  ;; .zshenv
  (with-output-to-file (string-append zsh-dir "/.zshenv")
    (lambda ()
      (format #t "export ZDOTDIR=\"${XDG_CONFIG_HOME:-$HOME}/.config/zsh\"~%")
      (format #t "export HISTFILE=\"$HOME/.cache/zsh/history\"~%")
      (format #t "export HISTSIZE=100000~%")
      (format #t "export SAVEHIST=100000~%")
      (format #t "mkdir -p \"$HOME/.cache/zsh\"~%")
      (format #t "~%")
      (format #t "GUIX_PROFILE=\"$HOME/.guix-profile\"~%")
      (format #t "if [ -f \"$GUIX_PROFILE/etc/profile\" ]; then~%")
      (format #t "  source \"$GUIX_PROFILE/etc/profile\"~%")
      (format #t "hash guix 2>/dev/null~%")
      (format #t "fi~%")
      (format #t "~%")
      (format #t "# Ensure setuid programs (sudo, ping, etc.) take priority~%")
      (format #t "export PATH=\"/run/privileged/bin:/run/setuid-programs:/run/current-system/profile/sbin:/home/neg/.guix-profile/sbin:$PATH:/run/current-system/profile/bin\"~%")
      (format #t "~%")
      (format #t "if [ -z \"$LD_LIBRARY_PATH\" ]; then~%")
      (format #t "  export LD_LIBRARY_PATH=\"/run/current-system/profile/lib\"~%")
      (format #t "else~%")
      (format #t "  export LD_LIBRARY_PATH=\"/run/current-system/profile/lib:$LD_LIBRARY_PATH\"~%")
      (format #t "fi~%")
      (format #t "~%")
      (format #t "export SOCKS5_PROXY=\"socks5h://127.0.0.1:10808\"~%")
      (format #t "export ALL_PROXY=\"$SOCKS5_PROXY\"~%")
      (format #t "export no_proxy=\"127.0.0.1,localhost,::1,.local\"~%")
      (format #t "export NO_PROXY=\"$no_proxy\"~%")
      (format #t "pgrep -x xray >/dev/null || nohup xray run -config ~a/.config/xray/config.json > /tmp/xray.log 2>&1 &~%" home)
      (format #t "~%")
      (format #t "export PASSWORD_STORE_DIR=\"$HOME/.local/share/pass\"~%")
      (format #t "# Disable p10k gitstatus daemon (not compiled in Guix)~%")
      (format #t "typeset -g POWERLEVEL9K_DISABLE_GITSTATUS=true~%")
      (format #t "typeset -gi _POWERLEVEL9K_DISABLE_GITSTATUS=1~%")))
  ;; .zshrc
  (with-output-to-file (string-append zsh-dir "/.zshrc")
    (lambda ()
      (format #t "# Guix VM zsh: load Guix plugins, then chezmoi config~%")
      (format #t "~%")
      (format #t "zi() { :; }~%")
      (format #t "zsh-defer() { shift; \"$@\" 2>/dev/null || :; }~%")
      (format #t "smartcache() { eval ~s; }~%" "$(\"$@\")")
      (format #t "~%")
      (format #t "for _d in /run/current-system/profile/share/zsh/plugins; do~%")
      (format #t "    for _p in zsh-autosuggestions zsh-syntax-highlighting; do~%")
      (format #t "        _f=\"$_d/$_p/$_p.zsh\"~%")
      (format #t "        [ -f \"$_f\" ] && source \"$_f\"~%")
      (format #t "    done~%")
      (format #t "done~%")
      (format #t "~%")
      (format #t "# Powerlevel10k (suppress gitstatus warnings)~%")
      (format #t "typeset -g POWERLEVEL9K_DISABLE_GITSTATUS=true~%")
      (format #t "typeset -gi _POWERLEVEL9K_DISABLE_GITSTATUS=1~%")
      (format #t "for _f in \\~%")
      (format #t "    /run/current-system/profile/share/zsh/powerlevel10k/powerlevel10k.zsh-theme \\~%")
      (format #t "    \"$HOME/.guix-profile/share/zsh/powerlevel10k/powerlevel10k.zsh-theme\"~%")
      (format #t "do~%")
      (format #t "    [ -f \"$_f\" ] && source \"$_f\" 2>/dev/null && break~%")
      (format #t "done~%")
      (format #t "~%")
      (format #t "# FZF integration (Guix fzf has no shell files)~%")
      (format #t "if (( $+commands[fzf] )); then~%")
      (format #t "    eval \"$(fzf --zsh)\" 2>/dev/null~%")
      (format #t "fi~%")
      (format #t "~%")
      (format #t "# guix pull with full parallelism (16 cores, 8 jobs)~%")
      (format #t "guix() {~%")
      (format #t "  if [[ $1 == pull ]]; then~%")
      (format #t "    command guix pull --cores=16 --max-jobs=8 \"${@:2}\"~%")
      (format #t "  else~%")
      (format #t "    command guix \"$@\"~%")
      (format #t "  fi~%")
      (format #t "}~%")
      (format #t "# Source chezmoi config (don't change ZDOTDIR)~%")

      ))
  ;; Copy .zshenv to home
  (copy-file (string-append zsh-dir "/.zshenv")
             (string-append home "/.zshenv"))
  (format #t "  .zshenv: ZDOTDIR -> ~a~%" zsh-dir)
  (format #t "  .zshrc: Guix plugins + powerlevel10k~%"))

    ;; Guix channels
  (let ((channels-file (string-append home "/.config/guix/channels.scm")))
    (system (string-append "mkdir -p " home "/.config/guix"))
    (with-output-to-file channels-file
      (lambda ()
        (format #t "(cons* (channel~%")
        (format #t "        (name 'cfg)~%")
        (format #t "        (url \"https://github.com/neg-serg/cfg.git\")~%")
        (format #t "        (branch \"main\"))~%")
        (format #t "       (channel~%")
        (format #t "        (name 'guix)~%")
        (format #t "        (url \"https://git.guix.gnu.org/guix.git\")~%")
        (format #t "        (branch \"master\")~%")
        (format #t "        (introduction~%")
        (format #t "         (make-channel-introduction~%")
        (format #t "          \"9edb3f66fd807b096b48283debdcddccfea34bad\"~%")
        (format #t "          (openpgp-fingerprint~%")
        (format #t "           \"BBB0 2DDF 2CEA F6A8 0D1D  E643 A2A0 6DF2 A33A 54FA\"))))~%")
        (format #t "       %default-channels)~%")))
    (format #t "  channels.scm created~%"))




;; zsh-native-syntax stub
(let ((stub-dir (string-append home "/.local/lib/zsh")))
  (system (string-append "mkdir -p " stub-dir))
  (with-output-to-file (string-append stub-dir "/zsh-native-syntax.plugin.zsh")
    (lambda ()
      (format #t "# Stub: zsh-native-syntax not available in Guix VM~%"))))
(format #t "  zsh-native-syntax stub created~%")

;; ── Step 7: Services ──
(step 7 "Starting services")
(sh sudo "herd" "restart" "ssh-daemon")
(for-each (lambda (svc)
            (sh sudo "herd" "enable" svc)
            (if (sh/ok? sudo "herd" "start" svc)
                (format #t "  ~a: started~%" svc)
                (format #t "  ~a~a: failed~a~%" yellow svc nc)))
          '("mpd" "unbound" "kanata" "mpdas"))

;; ── Summary ──
(newline)
(let* ((bin-dir (string-append profile "/bin"))
       (bins (if (access? bin-dir R_OK)
                 (length (scandir bin-dir (lambda (f) (not (dotfile? f)))))
                 0))
       (chezmoi-count (string->number (or (sh/cap "bash" "-c" "chezmoi managed 2>/dev/null | wc -l") "0")))
       (gopass-count (string->number (or (sh/cap "bash" "-c" "timeout 5 gopass list --flat 2>/dev/null | wc -l || echo 0") "0"))))
  (format #t "=============================================~%")
  (format #t "  Deployment Complete!~%")
  (format #t "  Binaries: ~a~%" bins)
  (format #t "  Chezmoi:  ~a files~%" chezmoi-count)
  (format #t "  Gopass:   ~a entries~%" gopass-count)
  (format #t "  System:   ~a~%" (sh/cap "guix" "system" "describe"))
  (format #t "  Zsh:      ~a with p10k + syntax highlighting~%"
          (sh/cap "which" "zsh"))
  (format #t "=============================================~%"))
