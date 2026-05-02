# TODO

Backlog of ideas and improvements. When ready to implement, run `/speckit.specify` with the description.

---

## Full HD Video Generation (LTX 2.3 22B)

LTX 2.3 22B distilled FP8 works on 7900 XTX (24GB, `--lowvram`). Tested: 512x320, 9 frames, 6 steps → 310s.
Goal: Full HD (1920x1080) at maximum quality.

**gen-video CLI integration:**
- [x] `--lowvram` flag added to `video-ai-generate.sh`
- [x] `__MODEL_FILE__`, `__STEPS__` placeholder substitution added
- [x] `ltx23-distilled-i2v.json` workflow created
- [ ] Update default model to `ltx-23-distilled-fp8`
- [ ] Add 1080p (1920x1080) and 720p (1280x720) resolution presets

**Quality parameters:**
- [ ] Steps: 8 (distilled optimal: 4-8)
- [ ] Test CFG 3.0-5.0 for best quality
- [ ] Width/height must be divisible by 32, frames = 8N+1 (9, 17, 25, 33...)

**Salt state updates:**
- [x] Gemma FP4 + text_projection + tokenizer.model download states added to video_ai.yaml
- [ ] LTX23 VAE download state (repo TBD)
- [ ] Workflow deployment for ltx23-distilled-t2v.json

---

## Browser profiles with persistent sessions

Multiple Floorp profiles with persistent data (cookies, localStorage, sessions). Goal: login to VK, YouTube and other popular sites via cookie import from other browsers.

- Named profiles with isolated storage
- Cookie import/export between profiles and browsers (Chrome, Firefox, Floorp)
- Profile switching via CLI or Hyprland keybind
- Salt-managed profile templates with pre-configured settings (extensions, privacy, proxy)
- Consider: `browser-cookie3` (Python) for cross-browser cookie extraction

---





## OpenCode Telegram Bots (manual setup)

`opencode-telegram` is now deployed and running.

Current runtime behavior:
- access is restricted to the owner user ID only
- bot only responds in private chat
- available models are restricted to DeepSeek (`deepseek-chat`, `deepseek-reasoner`), default = `deepseek-chat`

**Manual steps (Telegram-side):**
- [ ] Verify the running bot still responds correctly after token rotation / service restarts: `systemctl --user status opencode-telegram-bot opencode-serve`
- [x] telecode removed — decided it adds no value over opencode-telegram-bot + telethon-bridge

**Operational note:**
- [ ] Rotate the current `opencode-telegram-bot` token after validation; the token was pasted in chat and should be treated as compromised

**Optional enhancements:**
- [ ] Verify voice message flow end-to-end for `opencode-telegram-bot` (local `whisper-stt` on `127.0.0.1:8002/v1` now returns successful transcriptions)
- [ ] Decide whether to keep `piper-tts` as the primary always-on local TTS fallback for future Telegram/voice workflows, or switch to another local engine

---

## Telethon Bridge bring-up ✅

Сделано 2026-05-02. Сервис активен, авторизован как личный аккаунт (id=109503498).

- [x] Получены `api_id` (23244142) и `api_hash` из my.telegram.org через SOCKS5 прокси
- [x] Сохранены в gopass как `api/telegram-telethon-id` и `api/telegram-telethon-hash`
- [x] Перезапущен `./scripts/salt-apply.sh telethon_bridge` — конфиг с реальными ключами
- [x] Запущен `telethon-bridge-init` интерактивно — session-файл создан
- [x] Сервис запущен, health endpoint возвращает `{"connected": true, ...}`

**Известные проблемы:**
- ProxyPilot (порт 8317) не отвечает (connection reset) — предшествующая проблема, не связана с настройкой ключей/прокси. Bridge сообщает `proxypilot_ok: false`.
- Для AI-ответов через Telethon bridge нужно сначала починить ProxyPilot.

---

## Managed Telegram Bots (Bot API 9.6)

Bot API 9.6 (April 3, 2026) introduces Managed Bots — programmatic bot creation without BotFather.
A bot with `can_manage_bots: true` can create other bots via keyboard button, link, or Mini App,
and get their tokens via `getManagedBotToken(user_id)`.

**Documentation:** `docs/managed-telegram-bots.md`

- [ ] Enable bot management for the opencode-telegram-bot (or a dedicated manager bot) via @BotFather Mini App
- [ ] Verify `can_manage_bots: true` in `getMe` response
- [ ] Design multi-bot runner architecture: manager bot → creates per-task bots (monitoring, secrets, screenshots, VPN, etc.)
- [ ] Implement manager bot (Python/NodeJS) with Salt-managed systemd service
- [ ] Implement `getManagedBotToken` + `replaceManagedBotToken` for automated token lifecycle
- [ ] Add `t.me/newbot/` link flow as alternative creation method
- [ ] Add health checks for managed bots from the manager
- [ ] Document the multi-bot runner in `docs/managed-telegram-bots.md`
- [ ] Ensure token storage in gopass for each managed bot
- [ ] Rotate tokens periodically via `replaceManagedBotToken`

---

## Verify end-to-end alert pipeline for containerized services (FR-016)

After containerization lands, verify that container failures surface through the existing Loki/Grafana/`monitoring_alerts.sls` stack.

- [ ] Stop a containerized service after cutover and confirm alert fires through the existing channel
- [ ] Record outcome in 087 post-cutover notes

---

## Research / evaluation items

- [ ] Audit already-implemented docs and planning artifacts for obsolete references, duplicate examples, and dead guidance; queue any safe removals as a separate cleanup task.
- [x] Revisit `v` after the `nvr` restore — decision: keep `nvr`. Built-in `--remote-send`/`--remote-expr` lack `--remote-wait` (needed for `EDITOR`/`GIT_EDITOR`), `--remote-silent`, and tab control. `v` now also handles image files via `kitty +kitten icat`.

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

## Test suite improvements

Audit (2026-05-02): 393 tests, 0 failing.

### DONE

- [x] **Fix 4 failing tests (2026-05-01):**
  - `test_system_description_includes_hiddify_state_by_default` — updated default from `True` to `false` (hiddify disabled by default)
  - `test_hiddify_wrapper_launches_system_binary_after_loopback_fix` — removed (wrapper script deleted with hiddify cleanup)
  - `test_hiddify_fix_loopback_removes_ipv6_loopback_inbounds_and_rewrites_kde_proxy` — removed (fix-loopback script deleted)
  - `test_services_macro_exposes_config_replace_helper` — updated to check `container_service` macro (replaced `config_replace_with_service_control`)
- [x] **Create `tests/conftest.py`** — shared `REPO_ROOT`, `sys.path` setup, fixtures, pytest markers (`@pytest.mark.slow`, `@pytest.mark.integration`)
- [x] **Move `cmd.run` audit from report-only to failing** — 95% guard threshold in `test_cmdrun_audit.py:test_cmdrun_guard_coverage`
- [x] **Add `@pytest.mark.slow` to module-level render tests** — added `pytestmark = pytest.mark.slow` in both `test_macro_idempotency.py` and `test_cmdrun_audit.py`
- [x] **Deduplicate REPO_ROOT** — 15 copies replaced with `from tests import REPO_ROOT_PATH`; 0 remaining assignments
- [x] **Add tests for nanoclaw.sls and ollama.sls** — `test_nanoclaw.py` (113 lines), `test_ollama.py` (95 lines)
- [x] **Add YAML schema validation** — `test_yaml_schemas.py` covers packages.yaml, versions.yaml, hosts.yaml
- [x] **Add idempotency test** — `test_render_idempotent.py` renders states twice and compares


---

## wl-daemon: reconnect-on-broken-pipe instead of graceful shutdown

> **Upstream work** (`github.com/neg-serg/wl`, Rust code) — not a Salt repo task.
> Kept here as a tracking note.

When the Wayland compositor emits a fast output-remove-and-readd sequence (monitor hotplug, mode change, `hyprctl reload`, DPMS cycle), `wl-daemon` can race a pending `wl_display_flush()` against the now-closed `wl_output`. The flush returns `EPIPE` (Broken pipe), the error propagates as `wayland flush error` to the main loop, and the daemon currently chooses to `shutting down` cleanly (exit status 0).

**Proper fix (upstream):**
- [x] Treat dispatch/flush errors as recoverable — call `reconnect_wayland()` instead of `break`
- [ ] Add bounded retry (5 attempts over 10s) inside reconnect loop
- [ ] Emit clear log line: `wayland connection lost, reconnecting (attempt N/5)`
- [x] Keep `Restart=always` in wl.service as defense-in-depth

**Secondary cleanup** (cosmetic): `ExecStartPost=wl restore` retry-loop in the unit file fires before daemon's IPC socket is ready. Fix: `sd_notify(READY=1)` + `Type=notify` + drop sleep-based retry loop.

---

## Music Analysis Pipeline (essentia + annoy)

Scripts `music-highlevel`, `music-similar`, `music-index` require:
- `essentia` (provides `streaming_extractor_music`) — not in Arch repos, needs AUR or custom PKGBUILD
- `python-annoy` — approximate nearest neighbor library, pip or AUR

Create a separate Salt state (`music_analysis.sls` or extend `installers.sls`):
1. Build/install `essentia` via paru or PKGBUILD
2. Install `python-annoy` via pip_pkg macro
3. Idempotency checks for both

---

## Cosmetic improvements

**npmrc prefix**: global npm prefix is set to `/nonexistent` (from `/etc/npmrc`).
Create `~/.npmrc` with `prefix=$HOME/.local` via chezmoi (`dotfiles/dot_npmrc`).
Without this, `npm list -g` and `npm outdated -g` don't work (Salt workaround uses `--prefix`).

**ProxyPilot alias comment**: the `name/alias` format in `proxypilot.yaml.j2` is non-obvious. Add a comment explaining the mapping direction (alias = what the client sends, name = local model ID).

---

## Nyxt Browser Packaging

`nyxt-bin` — binary packaging of Nyxt browser. Requires investigation:
the current AUR package may be sufficient, or a custom PKGBUILD may be needed.

---

## Cache cleanup timers (systemd)

> Implements the task from TODO.ru.md — periodic cleanup of caches not covered by `paccache.timer`.

- [x] `scripts/cache-cleanup.sh` — single shell script cleaning paru, pip, npm, flatpak, cargo caches
- [x] `states/units/user/cache-cleanup.service` — `Type=oneshot` systemd user service
- [x] `states/units/user/cache-cleanup.timer` — weekly, with `Persistent=true` + `RandomizedDelaySec=2h`
- [x] Registered in `states/data/user_services.yaml` under `unit_files` + `enable_now_timers`

---

## IPv6 diagnostics and configuration

IPv6 testing revealed that the stack is functional but global addresses are missing and external connectivity is impossible.

**Issues:**
- ❌ Global IPv6 addresses missing (only link‑local `fe80::`)
- ❌ Default route (`default`) not configured
- ❌ Connectivity to external IPv6 hosts impossible (`Network is unreachable`)
- ✅ AAAA DNS resolution works
- ❌ Tunnel mechanisms (6to4, Teredo, Miredo) not installed
- ⚠️  `ip6tables` active with `DROP` policy on INPUT/FORWARD (may block ICMPv6)

**Actions:**
1. Check IPv6 settings on router/switch (enable SLAAC/DHCPv6)
2. If ISP doesn't provide IPv6, configure a tunnel (Hurricane Electric, SixXS)
3. If needed, temporarily disable `ufw` for IPv6 (`sudo ufw disable` for IPv6) or add rules for ICMPv6
4. For testing, use `ping -6` with interface specification (`-I`) or `curl --interface`
