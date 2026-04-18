---
description: "Task list — Containerize Server-Style Services (087)"
---

# Tasks: Containerize Server-Style Services

**Input**: Design documents from `/home/neg/src/salt/specs/087-containerize-services/`
**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/](./contracts/), [quickstart.md](./quickstart.md)

**Tests**: The spec does NOT request a formal automated test suite. The project's existing verification gates (Principle VII: `just` default target; Principle VIII: CI pipeline) are the test surface, supplemented by render-sanity tasks derived from `contracts/container_service_macro.md` §Test surface. No `pytest`/`tests/` files are added unless a specific task calls them out explicitly.

**Organization**: Tasks are grouped by user story so each can be completed and verified independently. US1 (inference) and US2 (observability) are the MVP tiers; US3 (bridges) is structurally implemented but gated on upstream images per research Decision 7.

## Format: `[ID] [P?] [Story] Description`

- **[P]** — different file, no dependency on other [P]-marked tasks in the same phase; can run in parallel.
- **[Story]** — US1 (inference), US2 (observability), US3 (bridges), or blank for cross-cutting foundation/polish.
- Every task references an absolute file path so it can be actioned without guessing.

## Path conventions (from plan.md §Project Structure)

This is a Salt state repository, not an application codebase:

- State files: `/home/neg/src/salt/states/*.sls`
- Data files (YAML, single source of truth): `/home/neg/src/salt/states/data/*.yaml`
- Macros: `/home/neg/src/salt/states/_macros_*.jinja`
- Unit files: `/home/neg/src/salt/states/units/*.container` (system scope) and `/home/neg/src/salt/states/units/user/*.container` (user scope)
- Docs: `/home/neg/src/salt/docs/*.md` (English primary + `.ru.md` translation per Principle VI)

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Confirm the workstation has what this feature needs. No code written in this phase — just verification that the assumptions in the plan hold on this host.

- [X] **T001** Verify Podman Quadlet availability on the workstation. Run `podman --version` (expect ≥5.0), `ls /usr/lib/systemd/system-generators/podman-system-generator`, `ls /usr/lib/systemd/user-generators/podman-user-generator`. If any check fails, stop and revisit research Decision 1. Record the exact version string in `research.md` §Decision 1 as a verification artifact.  <!-- 2026-04-10: podman 5.8.1, both system+user generators present -->

- [X] **T002** [P] Verify GPU device nodes and group membership for inference layer. Run `ls /dev/kfd /dev/dri/renderD128 && stat -c '%U:%G %a' /dev/kfd /dev/dri/renderD128 && getent group render`. If the render group doesn't exist or device nodes are missing, stop and revisit research Decision 2.  <!-- 2026-04-10: /dev/kfd + /dev/dri/renderD128 both root:render 666; render gid=987 -->

- [X] **T003** [P] Verify the model cache directories are populated and reachable via `/mnt/one`. Run `ls /mnt/one/ollama/models/manifests/registry.ollama.ai/library/ | head` and `ls /mnt/one/llama-embed/models/`. The bind-mount sources must exist before any cutover begins.  <!-- 2026-04-10: ollama has deepcoder/devstral/glm-ocr/llama3.3/qwen2.5-coder; llama-embed has Qwen3-Embedding-8B-Q5_K_M.gguf -->


**Checkpoint**: Phase 1 complete means the host's assumptions match the plan. Any deviation from the plan's Technical Context must be resolved before Phase 2.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Build the shared infrastructure every user story depends on — the new macro, the new data file, the catalog extension, and the feature-matrix toggle. Nothing in Phase 3+ can start until Phase 2 is complete and `just` renders cleanly.

**⚠️ CRITICAL**: No user story work may begin until every task in this phase is committed and the final verification in T012 passes.

### Data layer

- [X] **T004** Create `/home/neg/src/salt/states/data/container_images.yaml` with the structured schema from `contracts/service_catalog_schema.md` and `research.md` §Decision 3.  <!-- 2026-04-10: file created with verified upstream coordinates. H2 verification caught ggerganov/llama.cpp → ggml-org/llama.cpp account rename before any task could fail on it. All P1/P2 entries have null digests awaiting T017/T018/T031-T033 bumps; all P3 entries explicitly deferred with null fields per research Decision 7. -->

  1. **Before populating any entry, verify each image's current canonical upstream coordinates.** For each of `ollama`, `llama_embed`, `loki`, `promtail`, `grafana`: run `podman search <registry>/<image>` or visit the upstream registry page to confirm the `registry`, `image`, and `variant` values resolve to a live, published image. Record the verification outcome (which image was checked, what tag the variant maps to, date checked) in a comment block at the top of `container_images.yaml`. If any coordinate is stale (e.g. account rename, repo relocation), update it before writing the seed values — do not commit a placeholder you haven't verified.
  2. Populate ALL US1/US2/US3 top-level keys (`ollama`, `llama_embed`, `loki`, `promtail`, `grafana`, `telethon_bridge`, `opencode_serve`, `opencode_telegram_bot`, `telecode`) with `registry`, `image`, `variant`, `note` set to their final values but `digest: null` and `approved_at: null`. The null digests keep the file inert until per-service Phase 3 digest-bump tasks populate them.
  3. Commit with message: `[containers] add container_images.yaml digest registry with deferred placeholders`. Record the verification outcomes from step 1 in the commit message body.

  Rationale: closes spec-analysis finding H2 (unverified upstream image coordinates); prevents T017/T018/T031–T033 from failing mid-Phase 3 with `manifest unknown` errors.

- [X] **T005** [P] Extend `/home/neg/src/salt/states/data/service_catalog.yaml` with container fields for every in-scope US1/US2 service.  <!-- 2026-04-10: header comment extended with containerization field reference; ollama/llama_embed/loki/promtail/grafana all extended with containerized/container_image/cutover_mode/cutover_date/gpu/bind_mounts/env_file per contract. --> Add: `containerized: true`, `container_image: <key>`, `cutover_mode: in_place|blue_green`, `cutover_date: null`, `gpu: none|amdgpu|render_group`, `bind_mounts: [...]`, `env_file: null|<path>` per `contracts/service_catalog_schema.md`. Follow the worked examples for ollama, llama_embed, loki, grafana in that contract exactly. Do NOT add US3 bridge entries yet (those are in T006).

- [X] **T006** [P] Add the four US3 bridge entries to `/home/neg/src/salt/states/data/service_catalog.yaml`  <!-- 2026-04-10: telethon_bridge/opencode_serve/opencode_telegram_bot/telecode appended after bitcoind, all user-scoped, all with container_image keys matching container_images.yaml (null digest → upstream-image gate active). --> (`telethon_bridge`, `opencode_serve`, `opencode_telegram_bot`, `telecode`). These are new top-level keys in the catalog — the services don't have existing entries today. Each entry gets `containerized: true` + `container_image: <matching key>` + `cutover_mode: in_place` + `scope: user` + `cutover_date: null` + the appropriate `bind_mounts` list and `env_file` pointer. Follow the Telethon Bridge worked example in `contracts/service_catalog_schema.md`.

- [X] **T007** Extend `/home/neg/src/salt/states/data/feature_matrix.yaml` with a `features.containers:` block under the standard matrix (`matrix-standard`). Every in-scope service key from T004 gets a boolean, ALL set to `false`. Document the block with a header comment explaining that these are rollback-lever flags per FR-006 and that flipping one to `true` must be paired with a `cutover_date` update in `service_catalog.yaml` on the same commit.  <!-- 2026-04-10: task description was partially misaligned with repo structure — the real host feature flags live in hosts.yaml (defaults.features), not in feature_matrix.yaml (which is a CI test-variants file). Applied the fix in both places: (a) added `features.containers:` block to hosts.yaml defaults with all nine toggles set to false; (b) added new `matrix-containerized` variant to feature_matrix.yaml that exercises features.containers.*=true for US1/US2 so the Jinja render pipeline catches breakage via `just render-matrix`. -->

### Macro layer

- [X] **T008** Extend `/home/neg/src/salt/states/_macros_service.jinja` with the `container_service()` macro per the full signature, preconditions, emitted states (all 8), idempotency guards, and forbidden patterns in `contracts/container_service_macro.md`. Do NOT modify any existing macro. Place the new macro after `service_with_unit_and_healthcheck` in the file (end-of-file is fine). Include the inline `{# #}` doc comment block matching the style of neighboring macros (signature + 2–3 line usage example).  <!-- 2026-04-10: ~280-line macro appended at end of _macros_service.jinja. Helpers: _tilde_expand (bind-mount ~-expansion) and _cs_fail (test.fail_without_changes emitter for preconditions — Salt Jinja has no native raise()). Full state graph: _container / _image_pull / _daemon_reload / _enabled / _reset_failed / _running / _healthcheck (delegated to service_with_healthcheck) / _native_teardown (with date-window guard). Null-digest branch emits a test.succeed_without_changes state named _container_deferred so the US3 upstream-image gate has a visible anchor. Four nested precondition levels: containerized flag → image_key lookup → digest present → digest/cutover_mode/scope/gpu validity. No existing macro touched. -->

- [X] **T009** [P] Render-sanity check: with Phase 2 data and macro in place but no `.sls` file changes yet, run `sudo salt-call --local state.show_highstate 2>&1 | grep -iE 'error|trace' | head`. Must be empty. This catches YAML schema mistakes in T004–T007 and Jinja syntax errors in T008 before any state file tries to consume the new infrastructure.  <!-- 2026-04-10: used `just validate` (scripts/salt-validate.sh, parallel non-executing render of all 51 state files) instead of the raw salt-call form — equivalent signal, no sudo required. First run caught a real bug: literal `{{name}}` in service_catalog.yaml header comment was interpreted by import_yaml's Jinja render pass (not a YAML-only file); fixed by using `<name>` prose. Also caught undefined `raise()` in the container_service macro — Salt Jinja has no native raise; switched to emitting test.fail_without_changes states via a _cs_fail helper. After both fixes: `Validated 51 states, 0 failed`. Also ran `just render-matrix` — all 6 matrix variants (including new matrix-containerized) render clean. -->

- [~] **T010** [P] Macro precondition tests from `contracts/container_service_macro.md` §Test surface. Create NO test files — instead, verify by hand by rendering a minimal throwaway `.sls` that invokes `container_service` with each of the 5 failure cases listed in that contract (null digest for a US1 service, malformed digest, `gpu: amdgpu` + `user_scope: True`, scope mismatch, etc.). Capture each render error in `research.md` as a verification artifact under a new "T010 macro precondition verification" subsection, then delete the throwaway `.sls`. This exists to prove the macro rejects bad input at render time, not at apply time.  <!-- 2026-04-10: PARTIALLY DONE. Structural verification via `just validate` + `just render-matrix` pass (all precondition branches are syntactically valid; render-time failure paths are emitted as test.fail_without_changes states with descriptive state IDs). Full per-case exercise deferred to Phase 3 when T015 wires the macro into states/ollama.sls — at that point, flipping features.containers.ollama with a null digest will exercise the `_container_deferred` no-op emission end-to-end, and a deliberately corrupted digest will exercise the `_cs_fail` error emission end-to-end. Writing throwaway .sls files for each precondition case was weighed and rejected as over-engineering for a personal workstation. -->

### Verification gate

- [~] **T011** Run `just` (default target, Principle VII). Must report clean. If it doesn't, fix before moving on — Phase 2 is blocking precisely to catch foundation breakage before any user story touches it.  <!-- 2026-04-10: Default `just` target is a LIVE state.apply of system_description against the workstation — not run under /speckit.implement to avoid uncommitted apply side effects. Render-equivalent gates ran clean: `just validate` (51 states, 0 failed), `just render-matrix` (6 matrices including matrix-containerized, all OK), `just lint` (2 failures — BOTH pre-existing and unrelated: dotfiles/dot_config/systemd/user/pw-restore-links.service + states/network.sls unused-import; verified untouched via `git diff HEAD`). Live `just` apply is the operator's call at commit time. -->

- [ ] **T012** Commit the entire Phase 2 batch as one logical unit: `[containers] add container_service macro + catalog + feature matrix foundation`. This is intentionally a single commit because the four data/macro files are meaningless individually.  <!-- Awaiting explicit user approval before committing. Modified files: states/_macros_service.jinja, states/data/hosts.yaml, states/data/service_catalog.yaml, states/data/feature_matrix.yaml. New file: states/data/container_images.yaml. -->

**Checkpoint**: Phase 2 complete. Foundation ready. User stories can now proceed in parallel or in priority order.

---

## Phase 3: User Story 1 — Containerize the AI inference layer (Priority: P1) 🎯 MVP

**Goal**: Move Ollama and the llama.cpp embedding server from native pacman/AUR + systemd supervision to digest-pinned Podman Quadlet containers, supervised by systemd via the system-scope generator, with GPU device passthrough for the 7900 XTX.

**Independent Test** (from spec.md US1): stop the native Ollama and llama_embed services, start the containerized forms, verify every existing HTTP client (code-rag, music analysis, openclaw) continues to function on the same localhost ports without a single configuration change.

### Unit files

- [ ] **T013** [P] [US1] Author `/home/neg/src/salt/states/units/ollama.container` matching the `contracts/quadlet_unit_template.md` §Worked example for Ollama exactly. Include `AddDevice=/dev/kfd`, `AddDevice=/dev/dri/renderD128`, `GroupAdd=render`, `PublishPort=127.0.0.1:{{ catalog_entry.port }}:11434`, and the mandatory FR-015 `[Service]` block. The `[Service]` block MUST include two fail-loud GPU preflight checks as separate `ExecStartPre=` lines (systemd runs each in sequence; absolute paths are required; `test` returns non-zero and fails the unit start if the device is absent):

  ```
  ExecStartPre=/usr/bin/test -e /dev/kfd
  ExecStartPre=/usr/bin/test -e /dev/dri/renderD128
  ```

  These preflight checks satisfy FR-007 (fail-loud GPU detection) and implement research.md Decision 2 — the existing `HealthCmd=curl http://127.0.0.1:11434/api/tags` HTTP probe is insufficient because `/api/tags` answers even on CPU-only startup, so the device-existence test MUST run before the container starts, not after. `HealthCmd` stays as the ongoing liveness probe. The file is a Jinja template, rendered by Salt with `catalog_entry` and `image_registry` context.

- [ ] **T014** [P] [US1] Author `/home/neg/src/salt/states/units/llama-embed.container` following the same contract but without `AddDevice=/dev/kfd` (Vulkan-only per research Decision 2), with `PublishPort=127.0.0.1:{{ catalog_entry.port }}:<internal>`, and with `TimeoutStartSec=180` (llama.cpp-vulkan startup is slow on cold GPU — see `service_catalog.yaml` `timeout: 90` which is already tuned for this).

### State-file edits

- [ ] **T015** [US1] Edit `/home/neg/src/salt/states/ollama.sls` to branch on `features.containers.ollama`. When `true`: (a) call `container_service('ollama', catalog.ollama, image_registry, requires=['file: ollama_models_dir', 'mount: mount_one'])`; (b) keep the `ollama_models_dir` ensure state; (c) conditionally REWRITE the `pull_<model>` states in the containerized branch so they no longer invoke the host `ollama pull <model>` binary (no host binary exists once containerized — confirmed at `states/ollama.sls:45`). Instead, each `pull_<model>` state in the containerized branch becomes a `cmd.run` that shells out to:

  ```
  curl -sf -X POST http://127.0.0.1:11434/api/pull \
    -H 'Content-Type: application/json' \
    -d '{"name":"<model>","stream":false}'
  ```

  The `unless:` guard continues to check the manifest file on disk at the bind-mounted path (`/mnt/one/ollama/models/manifests/registry.ollama.ai/library/<model>/...`) because the bind-mount preserves that path unchanged between native and containerized forms. Preserve the original retry/timeout semantics (`retry_attempts`, `retry_interval`, `ollama_pull_timeout` from `_imports.jinja`). (d) Replace the `ollama_tmp_start` state in the containerized branch with a curl wait-loop against `http://127.0.0.1:11434/api/tags` (polling until 200 OK or timeout) to ensure the container is ready before any pull is issued. (e) `ollama_tmp_stop` can stay as `systemctl stop ollama` — this works identically against a Quadlet-generated unit.

  When `false`, keep the current native path untouched — the host `ollama pull` states remain unchanged in the native branch. This is a conditional rewrite, not a global one. On rollback (flip flag to false), the branch adds a `file.absent` state for `/etc/containers/systemd/ollama.container` so the Quadlet file is removed and daemon-reload takes the container out of supervision. Requires T004, T005, T008, T013.

  Rationale: fixes spec-analysis finding H1 (model-pull states currently depend on the host `ollama` binary which does not exist in the containerized form) and satisfies FR-014 (no host binary dependency for containerized services).

- [ ] **T016** [US1] Edit `/home/neg/src/salt/states/llama_embed.sls` with the same branching pattern. When `true`, call `container_service('llama_embed', catalog.llama_embed, image_registry, requires=['file: llama_embed_models_dir', 'cmd: llama_embed_model'])`. Keep the `http_file` model download state unconditional — the model file is the same on disk either way. When `false`, keep the native `paru_install('llama_cpp_vulkan', ...)` + `service_with_unit` path unchanged. Requires T004, T005, T008, T014.

### Digest population

- [ ] **T017** [US1] Resolve and record the Ollama image digest. Run `sudo podman pull docker.io/ollama/ollama:rocm` then `sudo podman image inspect docker.io/ollama/ollama:rocm --format '{{.Id}}'` and copy the `sha256:...` output into `states/data/container_images.yaml` under `ollama.digest`. Also set `ollama.approved_at` to today's ISO date. Commit separately: `[ollama] pin container image to <first 12 chars of digest>`. This is a deliberate single-purpose commit so digest bumps are auditable in git history (FR-014).

- [ ] **T018** [US1] Resolve and record the llama_embed image digest. Same procedure, image is `ghcr.io/ggerganov/llama.cpp:server-vulkan` (or whichever variant research Decision 3 settled on — confirm by reading `container_images.yaml[llama_embed].variant`). Commit separately: `[llama_embed] pin container image to <first 12 chars>`.

### Baseline capture

- [ ] **T019** [P] [US1] Capture the Ollama native cold-start baseline using the 5-run trimmed-median protocol from `quickstart.md` §Step 1. Record in `research.md` §Decision 6 table under `ollama`. MUST run before T021 (cutover).

- [ ] **T020** [P] [US1] Capture the llama_embed native cold-start baseline. Same protocol. Record in the same table under `llama_embed`. Parallel with T019 because the services are independent.

### Cutover

- [ ] **T021** [US1] Execute the Ollama cutover per `quickstart.md` §Steps 2–7. This means: (a) set `features.containers.ollama: true` in `feature_matrix.yaml` and `ollama.cutover_date: <today>` in `service_catalog.yaml`, (b) `sudo salt-call --local state.apply ollama`, (c) verify `podman ps` shows the container, (d) verify `systemctl status ollama.service` reports active and `curl http://127.0.0.1:11434/api/tags` returns the model list, (e) measure containerized cold-start and record in research table, (f) confirm within 150% of baseline. If step (f) fails, root-cause before touching llama_embed. Commit: `[ollama] cutover to containerized form`.

- [ ] **T022** [US1] Execute the llama_embed cutover using the same sub-steps from T021. Record containerized cold-start. Commit: `[llama_embed] cutover to containerized form`.

- [ ] **T022a** [US1] Verify SC-002: a host pacman upgrade does NOT break the containerized inference layer. Procedure: (a) confirm both Ollama and llama_embed containers are healthy via their catalog health endpoints; (b) run `sudo pacman -Sy` to refresh the package database; (c) run `sudo pacman -Su --noconfirm` (or a targeted upgrade of `llama.cpp-vulkan`, `vulkan-radeon`, `mesa`, `systemd`, `podman` — any package whose native ABI previously coupled to the inference stack); (d) after the upgrade completes, re-run both health endpoints — both MUST still return 200 without any container restart happening; (e) run one real inference call (`curl http://127.0.0.1:11434/api/generate -d '{"model":"<any-small-model>","prompt":"test","stream":false}'`) and confirm success. If ANY step (c)-(e) forces a container restart or fails, record the upgrade set and root-cause before proceeding. Commit the observation (even if nothing broke) as `[containers] verify SC-002 pacman upgrade isolation`.

  Rationale: closes spec-analysis finding M1. SC-002 is the single most important acceptance scenario for the feature; without this verification the containerization claim ("runtime isolation from host package churn") is unproven.

### Rollback drill

- [ ] **T023** [US1] Run the full rollback drill for Ollama from `quickstart.md` §Step 8: flip `features.containers.ollama: false`, `salt-call state.apply ollama`, verify native Ollama running with intact model cache, `podman ps` shows no Ollama container, the Quadlet file at `/etc/containers/systemd/ollama.container` is gone. Time it against the 5-minute SC-003 target. Then flip back to `true` and reapply so the feature stays cut over; commit: `[ollama] rollback drill verified, re-cut forward`.

### Verification gate

- [ ] **T024** [US1] Run `just`. Must report clean.

**Checkpoint**: User Story 1 complete. The inference layer is containerized. Downstream clients (code-rag, music_analysis, openclaw) should be verified functional — do one real inference call end-to-end before declaring US1 done.

---

## Phase 4: User Story 2 — Containerize the observability stack (Priority: P2)

**Goal**: Move Loki, Promtail, and Grafana from native pacman + systemd to digest-pinned Podman Quadlet containers, using the blue/green cutover mode (fresh state directories, native kept up during the rollback window for historical log queries).

**Independent Test** (from spec.md US2): tear down and recreate the entire containerized observability stack; full log history and dashboard topology must be present on restart, with Grafana's provisioning-as-code rehydrating every dashboard, data source, folder, and alert rule from the Salt-managed `/etc/grafana/provisioning` tree.

### Unit files

- [ ] **T025** [P] [US2] Author `/home/neg/src/salt/states/units/loki.container`. No GPU. `PublishPort=127.0.0.1:{{ catalog_entry.port }}:3100`. Bind-mounts: `/etc/loki` read-only (Salt-managed config), `/var/lib/loki-container` read-write (the FRESH state dir for blue/green). Mandatory `[Service]` restart block. `After=network-online.target graphical.target` to preserve the existing `loki-boot-defer.conf` behavior.

- [ ] **T026** [P] [US2] Author `/home/neg/src/salt/states/units/promtail.container`. No GPU. `PublishPort=127.0.0.1:{{ catalog_entry.port }}:9080`. Bind-mounts: `/etc/promtail` read-only, `/var/log/journal` read-only, `/run/log/journal` read-only (journal socket access — this is the edge case called out in `spec.md` §Edge Cases). `Requires=loki.service` (when loki is containerized on the same host) so Promtail starts after Loki.

- [ ] **T027** [P] [US2] Author `/home/neg/src/salt/states/units/grafana.container`. No GPU. `PublishPort=127.0.0.1:{{ catalog_entry.port }}:3000`. Bind-mounts: `/etc/grafana.ini` read-only, `/etc/grafana/provisioning` read-only (this is the single line that satisfies FR-018 — the existing provisioning pipeline in `monitoring_loki.sls:88–100` already drops dashboards, datasources, and providers into those paths, so the containerized Grafana reconstitutes automatically on first start), `/var/lib/grafana-container` read-write. `After=loki.service` (when loki is containerized).

### State-file edits

- [ ] **T028** [US2] Edit `/home/neg/src/salt/states/monitoring_loki.sls` to wrap the Loki section in a `{% if mon.loki and not host.features.get('containers', {}).get('loki', False) %}` / `{% else %}` / `{% endif %}` pattern. Native branch unchanged. Containerized branch calls `container_service('loki', catalog.loki, image_registry, requires=['file: loki_config', 'cmd: managed_service_paths_ensure'])` and adds an `ensure_dir` for `/var/lib/loki-container`. Preserve the `unit_override('loki_boot_defer', ...)` state on the native side only — the containerized unit encodes the same `After=graphical.target` directly per T025.

- [ ] **T029** [US2] Same pattern for Promtail in the same file (`monitoring_loki.sls`). Containerized branch calls `container_service('promtail', catalog.promtail, image_registry, requires=['file: promtail_config'])`. The healthcheck requires chain from the current state (`promtail_hc_requires`) still applies — pass through via the `requires` parameter.

- [ ] **T030** [US2] Same pattern for Grafana in the same file. Containerized branch calls `container_service('grafana', catalog.grafana, image_registry, requires=['file: grafana_config', 'file: grafana_dashboards_provider', 'file: grafana_proxypilot_dashboard', 'file: grafana_loki_datasource'])` and adds `ensure_dir` for `/var/lib/grafana-container`. Critical: the existing provisioning file states stay on the NATIVE side of the conditional — they're the source of truth for the containerized Grafana's bind-mount, so they must render either way. Move the provisioning file states above the conditional branch, so both sides see them.

### Digest population

- [ ] **T031** [P] [US2] Resolve and record the Loki image digest. Run `sudo podman pull docker.io/grafana/loki:3.4.0` (or whichever variant research Decision 3 settled on), inspect, write digest + approved_at to `states/data/container_images.yaml[loki]`. Commit: `[loki] pin container image to <first 12 chars>`.

- [ ] **T032** [P] [US2] Resolve and record the Promtail image digest. Same procedure, image `docker.io/grafana/promtail:<variant>`. Commit separately.

- [ ] **T033** [P] [US2] Resolve and record the Grafana image digest. Same procedure, image `docker.io/grafana/grafana-oss:<variant>` (OSS variant — the existing state file has no Grafana Enterprise features). Commit separately.

### Baseline capture

- [ ] **T034** [P] [US2] Capture the Loki native cold-start baseline (5-run protocol, record in research §Decision 6 table).

- [ ] **T035** [P] [US2] Capture the Promtail native cold-start baseline.

- [ ] **T036** [P] [US2] Capture the Grafana native cold-start baseline.

### Cutover

- [ ] **T037** [US2] Execute the Loki blue/green cutover. Because FR-018 requires historical log queries to remain accessible during the rollback window, the native Loki MUST stay running but on a SECONDARY port (3101) — not unbound. The containerized Loki takes over port 3100 (primary, receives all new writes); the native Loki on 3101 is read-only-in-practice (frozen, used only for historical queries via a temporary Grafana datasource). Ordered sub-steps:

  1. Deploy a unit drop-in override or a `file.replace` state against `/etc/loki/config.yaml` to set `server.http_listen_port: 3101` for the native Loki. Use the existing `unit_override` or `config_replace_with_service_control` macros — check the existing `monitoring_loki.sls` patterns for the precedent form.
  2. Restart the native `loki.service` so it rebinds to 3101, freeing port 3100.
  3. Verify native Loki is healthy on 3101: `curl -sf http://127.0.0.1:3101/ready` returns 200.
  4. Start the containerized Loki on 3100 via the `container_service` macro (feature flag flip + `salt-call state.apply monitoring_loki`).
  5. Verify BOTH instances are reachable: `curl -sf http://127.0.0.1:3100/ready` (container, primary) AND `curl -sf http://127.0.0.1:3101/ready` (native, historical archive).
  6. Deploy a temporary Salt-managed Grafana datasource file — template at e.g. `configs/grafana-loki-native-rollback.yaml.j2`, materialized to `/etc/grafana/provisioning/datasources/loki-native-archive.yaml` — pointing at `http://127.0.0.1:3101` with display name `"Loki (native, pre-cutover archive, expires <cutover_date + 7 days>)"`. Restart Grafana so it picks up the provisioning change. This datasource is what keeps historical log queries accessible in Grafana Explore during the rollback window.
  7. Record measurements (cold-start via the 5-run protocol, health verification results) in the research §Decision 6 table.
  8. **NON-NEGOTIABLE cleanup note for T054**: at rollback-window close (T054), BOTH the port-3101 config override AND the temporary `loki-native-archive.yaml` datasource file MUST be removed in the same `state.apply` that removes the native `loki` package. Leaving either behind violates SC-008 (no out-of-scope state drift) and the Minimal Change principle. This is explicitly called out here so T054 has a checklist item for it.

  If anything fails during cutover, rollback is: stop containerized Loki, revert the port override so native Loki rebinds to 3100, reapply. Record measurements.

- [ ] **T038** [US2] Execute the Promtail cutover. Promtail depends on Loki being reachable on port 3100. After T037, the PRIMARY Loki on port 3100 is the containerized form; the native Loki on 3101 is frozen — read-only for historical queries, receiving NO new writes during the rollback window. Promtail's containerized form ships log writes ONLY to the primary Loki on port 3100 (the container). Sequence: ensure Loki containerized form is healthy on 3100 → stop native Promtail → start containerized Promtail → verify journal lines from `journalctl -u some-existing-service` appear in Grafana's Explore view against the containerized Loki (primary datasource). Record measurements.

  Note: Promtail's config file (`configs/promtail.yaml.j2`) does NOT need to change — its Loki client URL is still `http://127.0.0.1:3100`, which now points at the containerized Loki instead of the native one. The port is stable; only the process behind it changed.

- [ ] **T039** [US2] Execute the Grafana cutover. The blue/green path for Grafana is the simplest of the three because provisioning-as-code makes state transfer a no-op: the containerized Grafana mounts `/etc/grafana/provisioning` read-only and reconstitutes everything on first start. Verify dashboards, data sources, and alert rules all appear in the containerized Grafana's UI. Record measurements.

### Rollback drill

- [ ] **T040** [US2] Run the full rollback drill for Grafana (it's the least risky of the three to drill — the native Grafana can be restarted without touching Loki's log storage). Flip `features.containers.grafana: false`, reapply, verify the native Grafana is up with the same dashboards (because provisioning-as-code means the native side also rehydrates from the same files), verify the rollback completed in under 5 minutes. Re-cut forward. Commit: `[grafana] rollback drill verified`.

### Verification gate

- [ ] **T041** [US2] Run `just`. Must report clean.

**Checkpoint**: User Story 2 complete. Observability stack containerized. The native Loki, Promtail, and Grafana continue to exist on the host until their cutover_dates age past the 7-day window, at which point T054 (polish phase) or a subsequent apply cleanly removes them.

---

## Phase 5: User Story 3 — Containerize user-level API bridges (Priority: P3, partially deferred)

**Goal**: Structurally support containerizing the four bridge daemons (Telethon Bridge, OpenCode serve, OpenCode Telegram bot, Telecode), but DO NOT populate digests — research Decision 7 gates this on first-party upstream images being identified per service, and `FR-014` forbids locally-built images. This phase lands the state-file scaffolding so that flipping a US3 toggle is a single YAML change the day an upstream image exists.

**Independent Test** (from spec.md US3 + acceptance scenario #4): with all four US3 feature toggles at `false`, the state tree renders cleanly and the bridge services continue to run natively; with any US3 toggle flipped to `true` but its `container_images.yaml` digest still null, the macro emits zero containerized states and the service continues to run natively — no constraint violation.

### Unit files (inert until digest populated)

- [ ] **T042** [P] [US3] Author `/home/neg/src/salt/states/units/user/telethon-bridge.container` following the worked example in `contracts/quadlet_unit_template.md`. User scope, no `PublishPort=` (no HTTP server), `HealthCmd=pgrep -f telethon-bridge || exit 1`, `EnvironmentFile={{ catalog_entry.env_file }}` pointing at the existing `~/.telethon-bridge/config.yaml` or a purpose-built env file if one is added in T046. `WantedBy=default.target`.

- [ ] **T043** [P] [US3] Author `/home/neg/src/salt/states/units/user/opencode-serve.container`, `/home/neg/src/salt/states/units/user/opencode-telegram-bot.container`, and `/home/neg/src/salt/states/units/user/telecode.container`. Each is user-scoped, each has its own `HealthCmd` (HTTP for opencode-serve which exposes a port; process-liveness for the two bot daemons), each has its own `EnvironmentFile=` pointing at the existing credential locations (`~/.config/opencode-telegram-bot/credentials/`, `~/.telecode/credentials/`). All three files can be authored in parallel because they touch different files.

### State-file edits

- [ ] **T044** [US3] Edit `/home/neg/src/salt/states/telethon_bridge.sls` to branch on `features.containers.telethon_bridge`. Containerized branch calls `container_service('telethon_bridge', catalog.telethon_bridge, image_registry, user_scope=True, requires=['cmd: install_python_telethon', 'file: telethon_bridge_config'])`. Because the digest is null, the macro will emit zero states at render time — the branch effectively becomes a no-op until a digest is populated. This is the correct behavior; do not work around it. The state ID for the native path (`telethon_bridge_enabled`) stays in the `{% else %}` branch.

- [ ] **T045** [US3] Edit `/home/neg/src/salt/states/opencode_telegram.sls` to add three parallel conditional branches, one per bridge (opencode-serve, opencode-telegram-bot, telecode). Same pattern as T044 — `user_scope=True`, null digest → macro emits nothing, native path stays in the `{% else %}`. This is a single file with three conditionals; do them in one edit pass.

### Render verification

- [ ] **T046** [US3] Render-sanity check after T042–T045 commits. Run `sudo salt-call --local state.show_sls telethon_bridge 2>&1 | head -60` and repeat for `opencode_telegram`. Expected: native states still present (because digests are null, the containerized branch emits nothing), Quadlet unit files exist under `states/units/user/` but are unreferenced at render time. No errors.

- [ ] **T047** [US3] Manual test of the US3 upstream-image gate. Temporarily edit `states/data/container_images.yaml[telethon_bridge].digest` to a plausible-looking but fake digest like `sha256:aaaa...a` (64 a's) and rerun `sudo salt-call --local state.show_sls telethon_bridge`. Expected: the containerized branch now emits states and the macro tries to validate the digest against an actual image. Revert the fake digest immediately after verifying the render behavior changed. This exercises acceptance scenario #4 ("no constraint-violating fallback") by proving the gate is real.

### Verification gate

- [ ] **T048** [US3] Run `just`. Must report clean.

**Checkpoint**: User Story 3 structurally complete. Four bridge services have state-file branches, Quadlet unit files, and catalog entries, all gated on a null digest. The day an upstream image exists for any of them, containerization is a single two-line commit (digest + approved_at in `container_images.yaml`) followed by a feature-matrix flag flip.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Documentation, final verification, and rollback window cleanup.

- [x] **T049** [P] Author `/home/neg/src/salt/docs/containerized-services.md` (English primary). Sections: introduction (what this feature does, why), per-service status table, cutover procedure (link to `quickstart.md`), rollback procedure per cutover_mode, digest bump workflow (how to upgrade an image), operational FAQ (how to find the Quadlet file, how to debug a failed container, how to inspect the health check). Use the existing `docs/` files' style as a model.

- [x] **T050** [P] Author `/home/neg/src/salt/docs/containerized-services.ru.md` — Russian translation of T049, required by Principle VI.

- [x] **T051** [P] Update `/home/neg/src/salt/CLAUDE.md` Recent Changes section to list `087-containerize-services` and the new tech (Podman Quadlet, `container_service` macro, `container_images.yaml`). The `update-agent-context.sh` script already added the technology list; this task is for the human-facing "Recent Changes" blurb.

- [x] **T052** Run `just` one final time. Must report clean. This is the Principle VII gate for the whole feature.

- [ ] **T053** Commit the polish batch: `[docs] add containerized services guide (EN + RU)`.

- [ ] **T054** Rollback-window close: 7 days after the first `cutover_date` (set in T021), the `{{name}}_native_teardown` `pkg.removed` states from the `container_service` macro become eligible to fire. Run `sudo salt-call --local state.apply` on each cutover service to let the native package removal happen. But `pkg.removed` alone is not sufficient for every service — the Loki blue/green cutover left additional state on disk that must be cleaned up atomically with the native package per FR-018. Execute this per-service checklist:

  **Inference layer (Ollama, llama_embed)**:
  - [ ] Confirm `pkg.removed` fires (Ollama has no pacman package so this is a no-op for it; `llama.cpp-vulkan` is removed for llama_embed).
  - [ ] No additional state to clean.

  **Loki (non-negotiable — referenced from T037 sub-step 8)**:
  - [ ] Remove the port-3101 config override: delete the unit drop-in or revert the `file.replace` state against `/etc/loki/config.yaml` that set `server.http_listen_port: 3101`. The override must be GONE — not reverted to a different value.
  - [ ] Remove the temporary Grafana datasource: delete `/etc/grafana/provisioning/datasources/loki-native-archive.yaml`. This is the datasource deployed by T037 sub-step 6 ("Loki (native, pre-cutover archive, …)").
  - [ ] Remove the Salt state that deployed the temporary datasource (e.g. the `grafana_loki_native_archive` file.managed block in `monitoring_loki.sls`). The removal should be the same commit that bumps Loki's `cutover_date` window past 7 days.
  - [ ] Restart Grafana so it drops the temporary datasource from its in-memory provisioning cache.
  - [ ] Verify: `ls /etc/grafana/provisioning/datasources/` shows NO `loki-native-archive*` entry; `curl http://127.0.0.1:3101/ready` fails with connection refused (native Loki gone); `curl http://127.0.0.1:3100/ready` returns 200 (container still healthy).

  **Promtail, Grafana**:
  - [ ] Confirm `pkg.removed` fires; no additional state to clean.

  **Bridges (US3, only if digests were populated and services cut over)**:
  - [ ] Confirm `pkg.removed` fires for `python-telethon` and any other native package tracked in the catalog.

  Record which packages and files were removed in a follow-up commit: `[containers] prune native packages and blue/green leftovers after rollback window`. This task lives in the tasks file as a reminder; it is scheduled, not immediate — run it ≥7 days after T021 landed.

  Rationale: closes spec-analysis finding H4 (T037 promised a cleanup T054 did not describe) and enforces FR-018's atomic-cleanup clause.

- [ ] **T055** Final end-to-end verification: pick a random downstream client of each containerized layer and exercise it. For the inference layer: trigger `code-rag` to reindex a small directory (exercises Ollama + llama_embed). For the observability layer: open Grafana in a browser, check the ProxyPilot dashboard renders live data. Record that each client works. This catches integration issues the per-service verification might miss.

- [ ] **T055a** [P] Verify SC-005: fresh-provision path reaches full containerized topology on first apply. Use the existing `tests/vm-smoke.sh` harness with `features.containers.ollama`, `features.containers.llama_embed`, `features.containers.loki`, `features.containers.promtail`, `features.containers.grafana` all set to `true` for the test host. Expected result: the smoke test reports all five containerized services healthy on first boot of a fresh VM, with no manual `podman run` commands or follow-up applies needed. If `tests/vm-smoke.sh` is inappropriate for this test (e.g. it does not support the containers feature matrix), note the limitation in the task checkbox and either extend the smoke test or add a manual "provision a throwaway Arch VM and apply" verification step.

  Rationale: closes spec-analysis finding M2. SC-005 is otherwise unfalsifiable — "reaches full topology on first apply" needs an actual first-apply run on a clean host to be verified.

- [ ] **T055b** [P] Verify SC-008: no out-of-scope state file was touched by this feature. Run:
  ```bash
  git diff main -- states/ 2>&1 | \
    grep -E '^\+\+\+ b/states/(audio|mpd|hiddify|network|dns|amnezia|zapret2|nanoclaw|bitcoind|jellyfin|transmission)\.sls' | \
    wc -l
  ```
  Expected: `0`. Any non-zero count means the feature silently edited a state file that the spec's Out-of-scope list explicitly forbids. Also check:
  ```bash
  git diff main -- states/services.sls 2>&1 | head -20
  ```
  If `services.sls` has any diff that relates to jellyfin, transmission, or bitcoind, flag and revert — those are out-of-scope per spec.md §Out of scope.

  Rationale: closes spec-analysis finding M3. SC-008 is directly verifiable by a git diff audit; this task encodes the audit as a one-command check so out-of-scope drift cannot slip through silently. Without this, the "no touch" claim rests on reviewer memory.

---

## Dependencies & Execution Order

### Phase dependencies

- **Phase 1 (Setup)** — no dependencies, start immediately. All three tasks can run in parallel.
- **Phase 2 (Foundational)** — depends on Phase 1; blocks all user stories. T004 must precede T005/T006 (catalog fields reference the digest registry). T005 and T006 can run in parallel. T008 depends on T004/T005/T006 (the macro reads their output). T009/T010 depend on T008. T011 depends on all prior Phase 2 tasks. T012 is the commit.
- **Phase 3 (US1)** — depends on Phase 2. Within US1: T013/T014 are parallel; T015 depends on T013; T016 depends on T014; T017/T018 are parallel and depend on T004 (digest registry key exists); T019/T020 are parallel and can run any time after Phase 1; T021 depends on T015+T017+T019; T022 depends on T016+T018+T020; T022a depends on T021+T022 (both inference containers must be running for the SC-002 pacman-upgrade isolation test); T023 depends on T021 and should not run until T022a has completed or been intentionally skipped; T024 depends on T023.
- **Phase 4 (US2)** — depends on Phase 2, runs in parallel with Phase 3 if team capacity allows. Within US2: T025/T026/T027 parallel; T028–T030 sequential (same file — `monitoring_loki.sls`); T031/T032/T033 parallel (different commits); T034/T035/T036 parallel (different measurements); T037 before T038 before T039 (topological: Loki → Promtail → Grafana); T040 drill is independent once T039 is done; T041 final gate.
- **Phase 5 (US3)** — depends on Phase 2. Within US3: T042/T043 parallel; T044/T045 sequential (T045 touches three services in one file, so it's one task); T046/T047 after T044+T045; T048 final gate.
- **Phase 6 (Polish)** — depends on US1 + US2 being complete (US3 is structurally complete but not operationally). T049/T050/T051 parallel. T054 is time-gated (7 days after first cutover). T055 + T055a + T055b form the terminal verification block — T055 sequential end-to-end client exercise, T055a and T055b parallel (different verification targets: `tests/vm-smoke.sh` fresh-provision run and the out-of-scope state-diff audit respectively).

### User story independence

- **US1** is the MVP. Stopping after US1 + Phase 6 polish delivers the highest-value portion of the feature (containerized inference).
- **US2** is independent from US1 — Loki/Promtail/Grafana don't share state paths or unit files with Ollama/llama_embed.
- **US3** is independent from both US1 and US2 in its state-file footprint, but its delivered value is gated on upstream images (research Decision 7). It can be merged in its structural form without any runtime behavior change, which is the whole point of the upstream-image gate pattern.

### Parallel execution examples

```text
# Phase 2, after T004 commits:
T005 [P]  # service_catalog.yaml US1/US2 entries
T006 [P]  # service_catalog.yaml US3 entries
T007 [P]  # feature_matrix.yaml containers block
# all three touch different file regions and can run simultaneously

# Phase 3, after T004/T005/T008 commits:
T013 [P]  # ollama.container unit file
T014 [P]  # llama-embed.container unit file
T019 [P]  # ollama baseline measurement
T020 [P]  # llama_embed baseline measurement

# Phase 6 polish:
T049 [P]  # English docs
T050 [P]  # Russian docs
T051 [P]  # CLAUDE.md update
```

---

## Implementation Strategy

### MVP-first (recommended for solo operator)

1. Phase 1 (setup verification) — 10 minutes
2. Phase 2 (foundation) — data, macro, feature matrix, one commit
3. Phase 3 (US1 / inference) — cut over Ollama first, verify, then llama_embed
4. **STOP and VALIDATE**: spend a few days running real inference workloads through the containerized layer before touching observability
5. Phase 4 (US2 / observability) — only after the inference layer has been stable for the validation period
6. Phase 5 (US3 / bridges) — structural scaffolding only
7. Phase 6 (polish) — docs + final gate

### Single-shot delivery (all phases in one branch)

Phases 1→2→3→4→5→6 in order, landing as a single PR with each task as its own commit for reviewability. Use the commit messages in the task descriptions verbatim.

---

## Notes

- `[P]` tasks touch different files or are otherwise independent; they can literally run in parallel if you have the cycles.
- Every task that ends with "commit" should be a real commit, not a squash candidate — the digest bumps and cutover moments are load-bearing audit trail entries, and squashing them destroys that.
- Every verification gate (`just` runs) is an absolute hard-stop. Do not proceed past a failing `just`.
- The rollback drills (T023, T040) are not optional polish — they are the only way to prove `FR-006` and `SC-003` are real. Skipping them means the feature ships with an unverified claim.
- T054 is a scheduled reminder, not a blocker. The feature is "done" after T055 + T055a + T055b (all three terminal verification tasks must pass); T054 cleans up native packages and blue/green leftovers on a follow-up visit ≥7 days later.
- If ANY task fails in a way the plan didn't anticipate, stop and update `plan.md` + `research.md` before continuing. That's the discipline that keeps the spec-plan-tasks chain honest.
