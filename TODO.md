# TODO

Backlog of ideas and improvements. When ready to implement, run `/speckit.specify` with the description.

---

## Full HD Video Generation (LTX 2.3 22B) ✅

LTX 2.3 22B distilled FP8 works on 7900 XTX (24GB, `--lowvram`).
Done: 1080p/720p presets, default model ltx-23-distilled-fp8, CFG 4.0, steps 8, frames 97 (8N+1), VAE from Kijai/LTX2.3_comfy, t2v+i2v workflows deployed.

**gen-video CLI integration:**
- [x] Update default model to `ltx-23-distilled-fp8`
- [x] Add 1080p (1920x1080) and 720p (1280x720) resolution presets

**Quality parameters:**
- [x] Steps: 8 (distilled optimal: 4-8)
- [x] Test CFG 3.0-5.0 for best quality — default 4.0
- [x] Width/height must be divisible by 32, frames = 8N+1 (9, 17, 25, 33...)

**Salt state updates:**
- [x] LTX23 VAE download state (repo TBD) — from Kijai/LTX2.3_comfy
- [x] Workflow deployment for ltx23-distilled-t2v.json

---

## Browser profiles with persistent sessions ✅

Implemented: `zen-profile` CLI (list/create/switch/cookies), rofi picker (Super+Alt+P), Salt state with Personal+Work templates. See `states/zen_profiles.sls`.

- [x] Named profiles with isolated storage
- [x] Cookie import/export between profiles and browsers (Chrome, Firefox, Floorp)
- [x] Profile switching via CLI or Hyprland keybind
- [x] Salt-managed profile templates with pre-configured settings

---

## Managed Telegram Bots (Bot API 9.6) ✅

Implemented: manager bot runner (`managed-bots-runner.py`), Salt state (`managed_bots.sls`), /start with request_managed_bot button, /bots listing, /rotate_token, gopass token storage, self-service allowlist. Spec at `specs/001-managed-telegram-bots/`.

- [x] Enable bot management for the opencode-telegram-bot (or a dedicated manager bot) via @BotFather Mini App
- [x] Verify `can_manage_bots: true` in `getMe` response
- [x] Design multi-bot runner architecture: manager bot → creates per-task bots (monitoring, secrets, screenshots, VPN, etc.)
- [x] Implement manager bot (Python/NodeJS) with Salt-managed systemd service
- [x] Implement `getManagedBotToken` + `replaceManagedBotToken` for automated token lifecycle
- [ ] Add `t.me/newbot/` link flow as alternative creation method
- [x] Add health checks for managed bots from the manager
- [x] Document the multi-bot runner in `docs/managed-telegram-bots.md`
- [x] Ensure token storage in gopass for each managed bot
- [x] Rotate tokens periodically via `replaceManagedBotToken`

---

## Verify end-to-end alert pipeline for containerized services (FR-016)

After containerization lands, verify that container failures surface through the existing Loki/Grafana/`monitoring_alerts.sls` stack.

- [ ] Stop a containerized service after cutover and confirm alert fires through the existing channel
- [ ] Record outcome in 087 post-cutover notes

---

## Research / evaluation items

- [ ] Audit already-implemented docs and planning artifacts for obsolete references, duplicate examples, and dead guidance; queue any safe removals as a separate cleanup task.

### Salt minimal rollout UX

- [ ] Rework `scripts/salt-apply.sh auto` from the current safe fallback (`system_description`) into an explainable minimal-rollout mode.
- [ ] Keep the default operator behavior conservative: when impact is unclear, fall back to `system_description` instead of risking a partial rollout that misses dependent states.
- [ ] Keep manual debugging first-class: `scripts/salt-apply.sh <state>` must continue to work unchanged, even after `auto` becomes smarter.
- [ ] Add a planning mode for `auto` so it can print `changed files -> selected states -> fallback reason` without executing Salt.
- [ ] Base `auto` primarily on git-changed files against a configurable base revision, with an explicit override for passing a file list manually during debugging.
- [ ] Map direct `states/**/*.sls` changes straight to their corresponding Salt state names.
- [ ] Add and maintain a small explicit impact map for shared inputs such as `states/data/*.yaml`, `_macros_*.jinja`, shared templates, unit files, and helper scripts that are known to affect multiple states.
- [ ] Prefer a repo-local, easy-to-read mapping file or shell/Python table over a “smart” hidden dependency engine, so the rollout logic stays inspectable and maintainable.
- [ ] Treat high-risk shared files conservatively at first, for example `_macros_service.jinja`, `_macros_pkg.jinja`, `states/data/services.yaml`, `states/data/service_catalog.yaml`, and similar broad inputs should trigger full `system_description` until a narrower rule is proven safe.
- [ ] Print the selected rollout scope before execution in `auto` mode so the operator can immediately see whether Salt is doing a narrow apply or a full fallback.
- [ ] Document the intended CLI shape before implementation stabilizes, including `scripts/salt-apply.sh auto`, `scripts/salt-apply.sh auto --plan`, `scripts/salt-apply.sh auto --base <rev>`, and `scripts/salt-apply.sh auto --files <path1,path2,...>`.
- [ ] Avoid trying to compute sub-state or state-ID-level minimal rollout inside a single `.sls` file; keep the unit of rollout at the Salt state level unless a real pain point proves finer granularity is worth the complexity.
- [ ] Add tests for `auto` scope selection rules before enabling any nontrivial narrowing logic; cover direct state edits, shared-input fallback, explain output, and manual override behavior.

### Salt apply planning and explain mode

- [ ] Add an explain-first planning layer for `scripts/salt-apply.sh` so operators can inspect scope and reasoning before execution when desired.
- [ ] Support a no-execution planning mode that prints the resolved state target, execution mode, and any safety fallback before running Salt.
- [ ] Keep explain output useful for both `scripts/salt-apply.sh <state>` and `scripts/salt-apply.sh auto`, so the interface stays consistent regardless of how scope was chosen.
- [ ] Show which inputs were used to compute the plan, for example explicit state argument, git base revision, manual file list, or high-risk shared-file fallback.
- [ ] Print `changed files -> selected states -> final execution target` in a compact operator-friendly format that is easy to skim in a terminal.
- [ ] When `auto` expands to full `system_description`, print the exact reason for the fallback instead of a vague message.
- [ ] Document and stabilize the difference between `--plan` and `--explain` before implementation grows: one should answer “what would run”, the other “why this scope was chosen”, or they should be merged if that split adds no value.
- [ ] Keep the planning layer read-only: it should not start the daemon, refresh baselines, or touch chezmoi when no execution flag was requested.
- [ ] Preserve current simple workflows by making planning optional; `scripts/salt-apply.sh <state>` should still execute directly without forcing an interactive confirmation step.
- [ ] Add tests for explain/plan output so fallback reasoning, selected state lists, and no-execution guarantees stay locked in as the rollout logic evolves.

### Hybrid drift monitoring

- [ ] Add a low-impact hybrid drift workflow that keeps cheap continuous drift checks separate from explicit `full-scan` runs.
- [ ] Keep the existing `salt-monitor` daemon as the long-running entry point for notifications and periodic checks instead of introducing a second monitoring service.
- [ ] Move drift state assembly into a dedicated helper that writes structured JSON status under `~/.cache/salt-monitor/`, so the daemon can report status cheaply without recomputing everything each time.
- [ ] Introduce a curated `states/data/drift_inventory.yaml` covering a small v1 set of managed files plus critical systemd unit policy for system and user scopes.
- [ ] Extend `scripts/pkg-drift.zsh` with a machine-readable `--json` mode so package drift can be reused by the structured helper instead of duplicated.
- [ ] Add drift-oriented monitor entry points such as fast-check, full-scan, status, and report modes, keeping `full-scan` manual by default.
- [ ] Refresh the authoritative drift baseline after a successful Salt + chezmoi apply while the maintenance lock is still active, so post-apply drift state reflects the intended system state.
- [ ] Add Just recipes for the drift workflow, for example quick drift check, explicit full drift scan, and structured/current status output.
- [ ] Keep the fast path intentionally narrow: package drift, curated file drift, enabled/disabled systemd policy drift, and runtime alert drift should be enough for v1.
- [ ] Avoid turning drift monitoring into a broad file-integrity scanner; prefer a small explicit inventory that stays understandable and cheap to maintain.
- [ ] Add tests for the inventory schema, structured drift helper, package drift JSON mode, and Salt/Justfile wiring before enabling periodic drift checks by default.

### Post-apply baseline refresh

- [ ] Refresh drift baseline only after a fully successful `scripts/salt-apply.sh` run, meaning Salt succeeded and the follow-up `chezmoi apply` path did not fail in a way that leaves the declared state incomplete.
- [ ] Keep the baseline refresh inside the existing maintenance-lock window so drift checks and alerts do not race the apply process and report transient inconsistency.
- [ ] Make the post-apply refresh update the authoritative expected snapshot used by drift reporting, rather than trying to infer expected state later from a stale cache.
- [ ] Record enough metadata with each refresh to explain what established the baseline, for example timestamp, hostname, git revision if available, Salt target, and whether the run was full `system_description` or a narrower state apply.
- [ ] Decide explicitly how narrow applies affect the baseline: either refresh only the touched subset with provenance, or block partial refreshes until a safe scoped-baseline model exists.
- [ ] Treat failed or degraded applies conservatively: if Salt fails, or if dotfiles remain unapplied in a way that affects the managed inventory, do not silently mark a new baseline as authoritative.
- [ ] Expose a manual baseline refresh path for recovery and debugging, but keep it clearly separate from normal drift checks so operators do not accidentally bless drift during diagnosis.
- [ ] Show in drift status/report output when the current baseline was last refreshed and from which apply mode, so operators can tell whether the snapshot is fresh enough to trust.
- [ ] Add tests that lock in baseline refresh gating rules, maintenance-lock behavior, and the relationship between successful apply paths and stored drift state.

### Nyxt dark theme support

Add dark theme configuration for Nyxt browser:
- Nyxt uses Lisp-based config (`~/.config/nyxt/auto-config.lisp`)
- Dark mode: `(define-configuration browser (default-theme 'dark))`
- System dark mode integration via `prefer-color-scheme`
- CSS injection for web content darkening if needed

### Home LLM cluster — exo / llama.cpp RPC

Future: try [exo](https://github.com/exo-explore/exo) (P2P cluster, auto-sharding, OpenAI-compatible API).

### SaluteSpeech — STT/TTS evaluation

Evaluate [SaluteSpeech](https://developers.sber.ru/docs/ru/salutespeech/overview) (Sber) for Russian-language speech recognition (STT) and synthesis (TTS).

- Freemium: ~1000 min/mo STT free tier
- Compare with local alternatives: `faster-whisper` (large-v3), Vosk
- Decision: cloud API (SaluteSpeech) vs self-hosted (Whisper on GPU)
- If adopted: Salt state for setup, API key in gopass, systemd service

---

## ~~Test suite improvements~~

~~Audit (2026-05-02): 393 tests, 0 failing.~~


---

## wl-daemon: reconnect-on-broken-pipe instead of graceful shutdown

> **Upstream work** (`github.com/neg-serg/wl`, Rust code) — not a Salt repo task.
> Kept here as a tracking note.

When the Wayland compositor emits a fast output-remove-and-readd sequence (monitor hotplug, mode change, `hyprctl reload`, DPMS cycle), `wl-daemon` can race a pending `wl_display_flush()` against the now-closed `wl_output`. The flush returns `EPIPE` (Broken pipe), the error propagates as `wayland flush error` to the main loop, and the daemon currently chooses to `shutting down` cleanly (exit status 0).

**Proper fix (upstream):**
- [ ] Add bounded retry (5 attempts over 10s) inside reconnect loop
- [ ] Emit clear log line: `wayland connection lost, reconnecting (attempt N/5)`

**Secondary cleanup** (cosmetic): `ExecStartPost=wl restore` retry-loop in the unit file fires before daemon's IPC socket is ready. Fix: `sd_notify(READY=1)` + `Type=notify` + drop sleep-based retry loop.

---

## ~~Music Analysis Pipeline (essentia + annoy)~~

~~Scripts `music-highlevel`, `music-similar`, `music-index` require:~~
~~- `essentia` (provides `streaming_extractor_music`) — not in Arch repos, needs AUR or custom PKGBUILD~~
~~- `python-annoy` — approximate nearest neighbor library, pip or AUR~~

~~Create a separate Salt state (`music_analysis.sls` or extend `installers.sls`):~~
~~1. Build/install `essentia` via paru or PKGBUILD~~
~~2. Install `python-annoy` via pip_pkg macro~~
~~3. Idempotency checks for both~~

---

## Cosmetic improvements

**npmrc prefix**: global npm prefix is set to `/nonexistent` (from `/etc/npmrc`).
Create `~/.npmrc` with `prefix=$HOME/.local` via chezmoi (`dotfiles/dot_npmrc`).
Without this, `npm list -g` and `npm outdated -g` don't work (Salt workaround uses `--prefix`).

**ProxyPilot alias comment**: the `name/alias` format in `proxypilot.yaml.j2` is non-obvious. Add a comment explaining the mapping direction (alias = what the client sends, name = local model ID).

---

## ~~Nyxt Browser Packaging~~

~~`nyxt-bin` — binary packaging of Nyxt browser. Deployed via `states/nyxt.sls`.~~

---

## IPv6 diagnostics and configuration

IPv6 testing revealed that the stack is functional but global addresses are missing and external connectivity is impossible.

**~~Infrastructure deployed (see states/ipv6.sls, states/ipv6_6to4.sls, states/ipv6_tunnel.sls):~~**
~~- Diagnostic script: `check-ipv6.sh` (deployed via Salt when `features.network.ipv6: true`)~~
~~- 6to4 tunnel: `tun6to4.service` systemd unit (gated by `features.network.ipv6_6to4`)~~
~~- HE.net tunnel: `he-tunnel.service` systemd unit + firewall + sysctl (gated by `features.network.ipv6_tunnel`)~~
~~- Sing-box DNS strategy auto-switches from `ipv4_only` → `prefer_ipv4` when either tunnel is enabled~~

**~~2026-05-03: 6to4 tested — anycast relay 192.88.99.1 unreachable via ISP.~~**
~~Tunnel interface (2002:b2ed:f82c::/16) and route (2000::/3) created successfully, but anycast relay doesn't respond — 100% packet loss, traceroute dies at hop 7. 6to4 effectively dead (RFC 7526 Historic, most operators dropped anycast).~~

**Remaining:**
- HE.net tunnel — requires manual registration at tunnelbroker.net, then `gopass insert api/he-tunnel` + `ipv6_tunnel: true`

**Issues:**
- ❌ Global IPv6 addresses missing (only link‑local `fe80::`)
- ❌ Default route (`default`) not configured
- ❌ Connectivity to external IPv6 hosts impossible (`Network is unreachable`)
- ✅ AAAA DNS resolution works

**Actions:**
1. Register at https://tunnelbroker.net, create Regular Tunnel
2. `gopass insert api/he-tunnel` with server_ipv4, client_ipv6, routed_prefix
3. `hosts.yaml: features.network.ipv6_tunnel: true`, then `just group network`
