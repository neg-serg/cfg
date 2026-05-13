# Feature Specification: Jinja Macros → Python Modules

**Feature Branch**: `006-jinja-to-python`
**Created**: 2026-05-13
**Status**: Draft
**Input**: "Move all Jinja macro business logic to Salt Python custom modules — zero Jinja macros remain. If something can't be moved, try again and write justification."

---

## User Stories

### US-1: Eliminate feature gating macros (P1)

Operator needs feature flags resolved in Python, not in opaque Jinja branching. `feature_enabled(host, name)` and `feature_default(name)` from `_macros_registry.jinja` become Python functions testable with pytest.

**Why P1**: Feature gating is the primary composability mechanism — every `.sls` file depends on it. Moving this to Python unlocks testing of the entire feature matrix without Salt.

**Independent test**: `pytest tests/ -k host_features` — verify feature_enabled() returns correct booleans for all 50+ features, all 9 matrix scenarios.

**Acceptance scenarios**:
- Given feature_registry.yaml with `mpd.default: true`, when `feature_default("mpd")` is called, then return `True`
- Given host with `features: {mpd: false}`, when `feature_enabled("mpd")` is called, then return `False`
- Given `_macros_registry.jinja` is deleted, all `.sls` files that used it still render correctly via `salt['host.feature_enabled'](...)` or Jinja filter

---

### US-2: Eliminate container_service macro (P1)

The 165-line `container_service()` macro in `_macros_container.jinja` generates 6-8 Salt states per container with preconditions, scope detection, bind-mount expansion, image resolution, and healthcheck wiring. All of this becomes a custom Salt state `container.managed`.

**Why P1**: Largest single macro; 14 containerized services depend on it. Moving to Python eliminates the most complex piece of Jinja logic.

**Independent test**: Render any containerized service `.sls` (e.g. `ollama.sls`) — verify it emits the same state IDs and structure. Run `salt-call state.show_sls ollama --out=json` and diff against baseline.

**Acceptance scenarios**:
- Given `container_image_registry` has `ollama.ghcr.io/ollama/ollama` with valid sha256 digest, when `container.managed` is called, then emit `ollama_container`, `ollama_image_pull`, `ollama_daemon_reload`, `ollama_enabled`, `ollama_running`, `ollama_healthcheck` states
- Given `container_image_registry` has invalid digest, when rendering, then fail with clear precondition error before any state executes
- Given user_scope=True with catalog scope=system, when rendering, then fail with scope_mismatch error
- Given `_macros_container.jinja` is deleted, all containerized services render identically

---

### US-3: Eliminate service management macros (P1)

`service_with_unit()`, `service_with_healthcheck()`, `ensure_running()`, `unit_override()`, `service_stopped()`, and all user-scoped variants (`user_service_file()`, `user_service_enable()`, `user_service_with_unit()`, `user_service_restart()`, `user_service_disable()`, `user_linger()`) move to custom states or execution modules.

**Why P1**: These 12 macros cover all service lifecycle management. Their combined ~500 lines of Jinja represent the core orchestration logic.

**Independent test**: `pytest tests/ -k service_modules` — verify each function produces correct Salt state data structures. Render any service `.sls` and compare state IDs.

**Acceptance scenarios**:
- Given `user_service_file('foo', 'foo.service')`, when rendered, then emit `foo: file.managed` at `~/.config/systemd/user/foo.service` with correct user/group
- Given `service_with_healthcheck('foo', 'foo', catalog=catalog)`, when catalog entry has `port: 9200` and `health_path: /_cluster/health`, then generate correct curl healthcheck command
- Given all service macros are deleted from `_macros_service.jinja` and `_macros_service_user.jinja`, all `.sls` files render without errors

---

### US-4: Eliminate installer macros (P2)

`curl_bin()`, `cargo_pkg()`, `pip_pkg()`, `curl_extract_tar()`, `curl_extract_zip()`, `git_clone_deploy()`, `git_clone_build()`, `http_file()`, `github_release_to()`, `npm_build_workflow()`, `download_font_zip()`, `install_catalog()` — all dependency installation scaffolding moves to Python execution modules.

**Why P2**: These are larger in volume (~560 lines) but individually simpler — each is a shell script template. Python versions will be testable and debuggable.

**Independent test**: `pytest tests/ -k install_modules` — verify each installer function returns correct `cmd.run` data. Render `installers.sls` and compare with baseline.

**Acceptance scenarios**:
- Given `curl_bin('aliae', 'https://.../aliae-linux-amd64')`, when rendered, then emit `install_aliae: cmd.run` with correct curl + chmod + mv
- Given `install_catalog(tools.curl_bin, ver, 'curl_bin')`, when catalog has 15 entries, then iterate all and dispatch to correct installer
- Given `_macros_install.jinja` is deleted, `installers.sls` and `installers_desktop.sls` render correctly

---

### US-5: Eliminate remaining macros (P3)

The tail macros: `paru_install()`, `simple_service()`, `pkgbuild_install()`, `flatpak_install()`, `ensure_dir()`, `remove_native_unit()`, `remove_native_package()`, `managed_sysusers_line()`, `managed_tmpfiles_line()`, `managed_identity_guard()`, `managed_path_guard()`, `managed_resource_value()`, `managed_mode_value()`, `config_file_edit()`, `render_service()`, `browser_extensions()`, `hyprpm_update/add/enable()`, `dconf_settings()`, `firefox_extension()`, `ipv6_tunnel()`, `download_cached()`, `ver_stamp()`, `gopass_secret()`, `tg_secret()`, `proxypilot_key()` move to Python.

**Why P3**: These are individually small but collectively significant (~800 lines). Some are trivial wrappers; some contain non-trivial logic.

**Independent test**: Full `just render-matrix` across all 9 scenarios passes. `pytest tests/` passes.

**Acceptance scenarios**:
- Given all `_macros_*.jinja` files contain zero `{% macro %}` definitions, all `.sls` files still render correctly
- Given `render-matrix` runs all 9 scenarios, zero template errors

---

## Edge Cases

- **Salt daemon context**: `gopass_secret()` currently detects daemon context (no GPG agent) and caches this. Python version must replicate the namespace-based caching to avoid repeated gopass failures.
- **Template whitespace control**: Some macros use `{%- ... -%}` for whitespace suppression. Python-rendered output must produce identical whitespace.
- **Jinja `namespace` objects**: `gopass_secret()` uses `{% set _gopass_ns = namespace(...) %}` for cross-macro state sharing. Python must replicate this persistent state.
- **Host attribute access**: Macros access `host.features.monitoring.loki` via Jinja dict traversal. Python must replicate the same traversal for `feature_enabled()`.
- **`slsutil.merge` mock**: The lint mock provides a fake `salt['slsutil.merge']`. The real Salt this function is still called from templates — but if all merge logic moves to Python, the mock can be removed.
- **`import_yaml` bridge**: `{% import_yaml 'data/X.yaml' as X %}` loads data into template namespace. Python module can replace this by loading YAML directly — but `.sls` files reference `X.field` inline. If Python provides a dict, templates access `X.field` the same way. No `.sls` change needed if the Python module pre-loads data into Jinja globals.

---

## Functional Requirements

| ID | Description | Must |
|----|-------------|------|
| FR-001 | All `{% macro %}` definitions in `states/_macros_*.jinja` files are removed | Yes |
| FR-002 | `feature_enabled(name)` is available as `salt['host.feature_enabled'](...)` | Yes |
| FR-003 | `container_service()` is available as custom state `container.managed` or execution module `container.deploy` | Yes |
| FR-004 | All service management functions are available as `salt['service.*']` or `salt['user_service.*']` | Yes |
| FR-005 | All installer functions are available as `salt['installer.*']` | Yes |
| FR-006 | `render_service()` (data-driven service loop) is available as `salt['service.render_service']` | Yes |
| FR-007 | `gopass_secret()` and convenience wrappers are available as `salt['secrets.get']` | Yes |
| FR-008 | Shared constants (`user`, `home`, `retry_attempts`, etc.) remain accessible to `.sls` files via Jinja globals set by a Python module | Yes |
| FR-009 | All 66 `.sls` files render without errors after migration | Yes |
| FR-010 | `just render-matrix` passes all 9 scenarios | Yes |
| FR-011 | `just lint` passes (excluding pre-existing non-macro issues) | Yes |
| FR-012 | Existing contracts in `salt_contracts.py` continue to pass | Yes |
| FR-013 | `salt_impact.py` data-to-state graph resolution is not broken | Yes |
| FR-014 | Python modules are placed in `states/_modules/` and `states/_states/` directories (standard Salt extension points) | Yes |
| FR-015 | Every Python module has corresponding pytest tests in `tests/` | Yes |

---

## Key Entities

- **`host_features` module** (`states/_modules/host_features.py`): Feature flag resolution — `feature_enabled(name)`, `feature_default(name)`, loaded from `feature_registry.yaml`
- **`container` state** (`states/_states/container.py`): Podman Quadlet container deployment as a custom Salt state — `container.managed(name, catalog_entry, image_registry, ...)`
- **`service` module** (`states/_modules/service.py`): System service lifecycle — `service_with_unit()`, `service_with_healthcheck()`, `ensure_running()`, `unit_override()`, `ensure_dir()`, `remove_native_unit()`, `remove_native_package()`, `managed_resource_value()`
- **`user_service` module** (`states/_modules/user_service.py`): User-scoped service lifecycle — `service_file()`, `service_enable()`, `service_with_unit()`, `service_restart()`, `service_disable()`, `linger()`
- **`installer` module** (`states/_modules/installer.py`): Package installation methods — `curl_bin()`, `cargo_pkg()`, `pip_pkg()`, `http_file()`, `git_clone_deploy()`, `git_clone_build()`, `download_font_zip()`, `github_release_to()`, `npm_build_workflow()`, `install_catalog()`
- **`pkg` module** (`states/_modules/pkg.py`): Package manager wrappers — `paru_install()`, `simple_service()`, `pkgbuild_install()`, `flatpak_install()`
- **`secrets` module** (`states/_modules/secrets.py`): Secret resolution with caching — `gopass_secret(key, fallback_cmd)`, `proxypilot_key()`, `tg_secret()`
- **`config` module** (`states/_modules/config.py`): Config file editing — `config_file_edit()`
- **`desktop` module** (`states/_modules/desktop.py`): Desktop session — `browser_extensions()`, `hyprpm_update()`, `hyprpm_add()`, `hyprpm_enable()`, `dconf_settings()`
- **`data_loader` module** (`states/_modules/data_loader.py`): Pre-loads all YAML data files and injects them into Jinja globals, replacing inline `{% import_yaml %}` calls on a per-state basis
- **`common` module** (`states/_modules/common.py`): Shared constants (`user`, `home`, `retry_attempts`, `ver_dir`, `download_cache`, etc.) injected as Jinja globals via `data_loader`

---

## Success Criteria

| ID | Metric | Type |
|----|--------|------|
| SC-001 | Zero `{% macro %}` blocks exist in any `states/_macros_*.jinja` file | quality |
| SC-002 | All 66 `.sls` files render to identical state ID sets as before migration | quality |
| SC-003 | `just render-matrix` completes with zero errors across all 9 scenarios | quality |
| SC-004 | At least 30 pytest tests exist covering the new Python modules | quality |
| SC-005 | `just lint` shows no new violations introduced by migration | quality |
| SC-006 | All existing Salt contracts (`salt_contracts.py`) pass unchanged | quality |
| SC-007 | `salt_impact.py` correctly resolves data→state dependencies for all migrated states | quality |
| SC-008 | All `_macros_*.jinja` files are either empty (only imports) or deleted | quality |

---

## Non-Migratable Items (Justification Required)

Items that cannot be moved from Jinja to Python must be listed here with technical justification. During implementation, each candidate must be:

1. Attempted
2. If impossible, documented with specific technical blocker
3. Re-attempted with alternative approach (different Salt extension point, different abstraction)
4. If still impossible, added to this section

**Pre-identified non-migratable candidates:**

1. **`{% import_yaml 'data/X.yaml' as X %}`** — This is a Salt built-in Jinja tag extension, not a user-defined macro. Alternatives: pre-load all data in Python module and inject as Jinja globals, removing the need for explicit `import_yaml` in .sls files.
2. **`{{ var | tojson }}` and `{{ var | replace(...) }}`** — Jinja built-in filters, not macros. These are template rendering, not business logic.
3. **`{% for item in list %}` / `{% if condition %}` in .sls files** — Jinja control flow embedded in state files. These are part of the template structure, not reusable macros. Moving them would mean replacing Jinja as the template engine entirely — out of scope.

---

## Assumptions

- Salt 3006.x supports custom `_modules/`, `_states/`, and `_jinja_filters/` in file_roots
- Salt's `salt['module.func']()` calling convention works identically in Jinja templates
- Custom state modules can return the same data structures as built-in states
- The `just render-matrix` mock environment can be adapted to provide mock Salt modules
- Migration is reversible — old macros can be kept as compatibility shims during transition
