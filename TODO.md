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

## ydotool service not enabled

`ydotool.service` (systemd user unit) is installed but **disabled and inactive**.
Hyprland MCP tools (`mouse_click`, `click_text`, `key_press`, etc.) depend on `ydotoold` running.

**Fix**: Enable the user service in Salt (`user_services.sls` or similar):
```
systemctl --user enable --now ydotool.service
```

Without this, the Hyprland MCP server's mouse/keyboard automation tools fail silently or error on click/type operations. Screenshots still work (they use `grim`/`slurp`, not ydotool).

---

## tg-cli: register own Telegram API credentials

`tg-cli` (pipx, `kabi-tg-cli`) is installed and working with default Telegram Desktop credentials (`api_id=2040`).
This increases the risk of account restrictions from Telegram.

Current blocker: direct access to `https://my.telegram.org` times out on this network.
`curl --socks5 127.0.0.1:10808 https://my.telegram.org` works, so browser access must go through the local Telegram SOCKS5 proxy.

- [ ] Restart Zen Browser after running `python3 scripts/set-zen-proxy telegram`
- [ ] Re-test `https://my.telegram.org` in Zen with Telegram SOCKS5 proxy enabled
- [ ] If Zen still shows generic `ERROR`, retry in a clean/private window and/or another browser routed through `127.0.0.1:10808`

- [ ] Register own app at https://my.telegram.org/apps (requires SMS/Telegram code)
- [ ] Create `~/.config/tg-cli/.env` with `TG_API_ID` and `TG_API_HASH`
- [ ] Re-authenticate: `tg status` (will pick up new credentials)
- [ ] Optionally: store credentials in gopass (`api/telegram-api`)

Note: my.telegram.org form may silently reject — known issue, retry later or from a different browser/IP.

---

## OpenCode Telegram Bots (manual setup)

`opencode-telegram` is now deployed and running.

Current runtime behavior:
- access is restricted to the owner user ID only
- bot only responds in private chat
- available models are restricted to DeepSeek (`deepseek-chat`, `deepseek-reasoner`), default = `deepseek-chat`

**Manual steps (Telegram-side):**
- [ ] Create bot via @BotFather for telecode → `gopass insert api/telecode-telegram`
- [ ] Verify the running bot still responds correctly after token rotation / service restarts: `systemctl --user status opencode-telegram-bot opencode-serve`
- [ ] Decide whether `telecode` is still needed as a second Telegram stack or should be removed/frozen

**Operational note:**
- [ ] Rotate the current `opencode-telegram-bot` token after validation; the token was pasted in chat and should be treated as compromised

**Optional enhancements:**
- [ ] Add more workspaces to telecode config (currently only `~/src/salt`)
- [ ] Configure STT (voice transcription) for opencode-telegram-bot
- [ ] Add telecode to `salt-monitor` health checks

---

## Telethon Bridge bring-up

Repository/runtime prep is done, but the service is still blocked on external Telegram MTProto prerequisites.

Current state:
- `telethon_bridge` feature is enabled for `telfir`
- config/runtime paths were moved to XDG-style directories
- service healthcheck is honest now and stays red until a real session exists
- `telethon-bridge-init` now fails with a clear error instead of traceback when MTProto credentials are missing

Remaining blockers:
- [ ] Obtain `api_id` and `api_hash` from `https://my.telegram.org/apps`
- [ ] Store them in `gopass` as `api/telegram-telethon-id` and `api/telegram-telethon-hash`
- [ ] Re-run `./scripts/salt-apply.sh telethon_bridge`
- [ ] Run `telethon-bridge-init` interactively to create `~/.local/state/telethon-bridge/telethon.session`
- [ ] Start and verify: `systemctl --user restart telethon-bridge && curl -s http://127.0.0.1:8319/health`

Note: `my.telegram.org` currently times out directly on this network; use the local Telegram SOCKS5 proxy path from the section above.

---

## Verify end-to-end alert pipeline for containerized services (FR-016)

After containerization lands, verify that container failures surface through the existing Loki/Grafana/`monitoring_alerts.sls` stack.

- [ ] Stop a containerized service after cutover and confirm alert fires through the existing channel
- [ ] Record outcome in 087 post-cutover notes

---

## Hyprland hotkey UX

- [ ] Add an optional hierarchical key-hint mode generated from `dotfiles/dot_config/hypr/shortcuts.yaml` as an alternative to the search-first `Mod4+/` launcher, so grouped prefixes can expand into a structured on-screen help tree without diverging from the search catalog.

---

## Research / evaluation items

- [ ] Audit already-implemented docs and planning artifacts for obsolete references, duplicate examples, and dead guidance; queue any safe removals as a separate cleanup task.
- [ ] Revisit `v` after the `nvr` restore: Neovim has built-in remote/server flags, so a future migration away from `nvr` is possible, but it needs a careful proof that the attach flow and UX stay correct.

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

When building a multi-node home cluster, evaluate distributed LLM inference options:

- **[exo](https://github.com/exo-explore/exo)** (~42k stars) — P2P cluster, auto-discovery via libp2p, auto-sharding across heterogeneous devices. AMD ROCm supported via tinygrad. No AUR package (pip-only). OpenAI-compatible API — plugs into ProxyPilot. Best for: models >VRAM (70B–235B class).
- **llama.cpp RPC backend** — already installed (`llama.cpp-vulkan`). Run `rpc-server` on remote nodes, connect via `--rpc host:50052`. No extra dependencies. Vulkan support. Best for: extending existing stack with minimal overhead.
- **Ollama cluster mode** — in development upstream, may land before cluster is built. Monitor progress.

Decision: prefer llama.cpp RPC (already in stack, AUR package, Vulkan). Revisit exo when AMD ROCm support matures and/or AUR package appears.

### SaluteSpeech — STT/TTS evaluation

Evaluate [SaluteSpeech](https://developers.sber.ru/docs/ru/salutespeech/overview) (Sber) for Russian-language speech recognition (STT) and synthesis (TTS).

- Freemium: ~1000 min/mo STT free tier
- Compare with local alternatives: `faster-whisper` (large-v3), Vosk
- Decision: cloud API (SaluteSpeech) vs self-hosted (Whisper on GPU)
- If adopted: Salt state for setup, API key in gopass, systemd service

---

## Test suite improvements

Audit (2026-04-15): 106 tests across 19 files + 1 shell script. 3 failing, several gaps.

### HIGH PRIORITY

- [ ] **Fix 3 failing tests:**
  - `test_managed_resources_inventory_covers_phase1_services` — remove `adguardhome`, `bitcoind` (now containerized)
  - `test_transmission_uses_shared_config_replace_helper` — update to match consolidated services.sls pattern
- [ ] **Create `tests/conftest.py`** — shared `REPO_ROOT`, `sys.path` setup, fixtures, pytest markers (`@pytest.mark.slow`, `@pytest.mark.integration`)
- [ ] **Move `cmd.run` audit from report-only to failing** — currently 70/499 unguarded states silently pass checks. Add threshold-based fail.
- [ ] **Add `@pytest.mark.slow` to module-level render tests** — `test_macro_idempotency.py` and `test_cmdrun_audit.py` render ALL .sls at import time

### MEDIUM PRIORITY

- [ ] **Add service catalog consistency tests** — verify `service_catalog.yaml` entries have valid units, templates exist, packages resolve
- [ ] **Add macro output tests** — test `_macros_service.jinja` helpers produce expected state structures with specific arguments
- [ ] **Add tests for critical scripts:** `update-tools.py`, `salt-daemon.py`, `lint-jinja.py`
- [ ] **Add containerized services tests** — verify Quadlet files exist for declared containers, bind-mounts match state paths
- [ ] **Deduplicate REPO_ROOT** — remove ~15 copies of `REPO_ROOT = Path(__file__).resolve().parent.parent` after conftest.py exists

### LOWER PRIORITY

- [ ] Add tests for nanoclaw.sls and ollama.sls (key user-facing services)
- [ ] Add YAML schema validation for packages.yaml, versions.yaml, hosts.yaml
- [ ] Add idempotency test — render states twice, compare output

---

## wl-daemon: reconnect-on-broken-pipe instead of graceful shutdown

> **Upstream work** (`github.com/neg-serg/wl`, Rust code) — not a Salt repo task.
> Kept here as a tracking note.

When the Wayland compositor emits a fast output-remove-and-readd sequence (monitor hotplug, mode change, `hyprctl reload`, DPMS cycle), `wl-daemon` can race a pending `wl_display_flush()` against the now-closed `wl_output`. The flush returns `EPIPE` (Broken pipe), the error propagates as `wayland flush error` to the main loop, and the daemon currently chooses to `shutting down` cleanly (exit status 0).

**Proper fix (upstream):**
- [ ] Treat `EPIPE` on `wl_display_flush()` as recoverable rather than fatal
- [ ] Wrap reconnect behind bounded retry (5 attempts over 10s)
- [ ] Emit clear log line: `wayland connection lost, reconnecting (attempt N/5)`
- [ ] Keep `Restart=always` in wl.service as defense-in-depth

**Secondary cleanup** (cosmetic): `ExecStartPost=wl restore` retry-loop in the unit file fires before daemon's IPC socket is ready. Fix: `sd_notify(READY=1)` + `Type=notify` + drop sleep-based retry loop.

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
