# Implementation Plan: Jinja Macros → Python Modules

**Branch**: `006-jinja-to-python`
**Date**: 2026-05-13
**Spec**: [spec.md](./spec.md)
**Input**: "Move all Jinja macro business logic to Salt Python custom modules — zero Jinja macros remain"

---

## Summary

Migrate all ~2300 lines of Jinja macro logic from 10 `_macros_*.jinja` files to Salt Python custom modules (`_modules/`, `_states/`). The macros remain functionally identical but execute in Python with pytest-testable code. After migration, `_macros_*.jinja` files contain zero `{% macro %}` definitions — only `{% import_yaml %}` and `{% set %}` constant declarations.

---

## Technical Context

| Field | Value |
|---|---|
| language_version | Python 3.12+ |
| primary_dependencies | Salt 3006.x, Jinja2, PyYAML |
| storage | YAML files (`states/data/*.yaml`) |
| testing | pytest |
| target_platform | CachyOS (Arch Linux) |
| project_type | Salt configuration management (masterless) |
| performance_goals | Template render time unchanged (macros are evaluated at render time regardless of location) |
| constraints | Salt's `salt['module.func']()` calling convention; custom states must return standard Salt data structures; `just render-matrix` mock env must be adapted |
| scale_scope | 66 `.sls` files, 10 macro files, ~2300 macro lines, 9 matrix scenarios |

---

## Constitution Check

| Gate | Passed | Notes |
|---|---|---|
| I. Idempotency | YES | Python modules preserve all existing `creates:`, `unless:`, `onlyif:` guards. Identical state output. |
| II. Network Resilience | YES | Python modules emit same `retry:`/`parallel:`/curl flags as macros. |
| III. Secrets Isolation | YES | `gopass_secret()` moves to Python, preserves same caching, fallback, and gopass path logic. No plaintext secrets. |
| IV. Macro-First | **VIOLATION** | See Complexity Tracking below. Macros are being REMOVED and replaced with Python modules. |
| V. Minimal Change | YES | Only macros move; no `.sls` restructuring, no new features. Scope is strictly migration. |
| VI. Convention Adherence | YES | State IDs unchanged. Commit style unchanged. Shell scripts unchanged. |
| VII. Verification Gate | YES | `just render-matrix` passes after each phase. |

---

## Complexity Tracking

### Violation: Principle IV (Macro-First)

**What is violated**: Constitution requires all repeating infrastructure patterns to use Jinja macros from `_macros_*.jinja`. This feature removes ALL macros.

**Why it's needed**: Jinja macros are untestable without Salt runtime, impossible to debug with standard Python tooling, and contain ~2300 lines of business logic that would benefit from static type checking, unit testing, and IDE support. Moving to Python custom modules:
- Makes every function testable with `pytest`
- Enables `pdb`/IDE debugging of business logic
- Allows static type checking
- Preserves identical behavior (same Salt state output)

**What simpler alternative was rejected**: 
1. Keep macros + add Python wrappers (two sources of truth) — rejected, violates V (Minimal Change) worse than the violation
2. Keep macros + write integration tests via salt-call — rejected, too slow, doesn't give unit-level coverage
3. Hybrid: move only feature_enabled() to Python, keep rest as macros — rejected, doesn't achieve the goal of eliminating Jinja business logic

**Constitution amendment needed**: Principle IV should be updated from "Jinja macros from `_macros_*.jinja`" to "shared reusable modules (Python `_modules/` and `_states/` preferred, Jinja `_macros_*.jinja` accepted for legacy)." I.e. the principle's *intent* (no inline duplication) is preserved; the *mechanism* (Jinja vs Python) is updated.

---

## Project Structure

### Source Layout

```
states/
├── _modules/              # NEW: Salt execution modules
│   ├── __init__.py
│   ├── host_features.py   # feature_enabled(), feature_default()
│   ├── service.py         # system service lifecycle
│   ├── user_service.py    # user-scoped service lifecycle
│   ├── installer.py       # curl_bin, cargo_pkg, pip_pkg, etc.
│   ├── pkg.py             # paru_install, pkgbuild_install, flatpak_install
│   ├── secrets.py         # gopass_secret() and wrappers
│   ├── config.py          # config_file_edit()
│   ├── desktop.py         # browser_extensions, hyprpm, dconf
│   ├── common.py          # shared constants and helpers
│   └── data_loader.py     # YAML preloader + Jinja globals injector
├── _states/               # NEW: Salt custom state modules
│   └── container.py       # container.managed state
├── _macros_registry.jinja # → becomes: only {% import_yaml %} (or deleted if data_loader handles it)
├── _macros_container.jinja# → deleted (→ _states/container.py)
├── _macros_service.jinja  # → reduced to constants, macros → _modules/service.py
├── _macros_service_user.jinja # → deleted (→ _modules/user_service.py)
├── _macros_install.jinja  # → deleted (→ _modules/installer.py)
├── _macros_pkg.jinja      # → deleted (→ _modules/pkg.py)
├── _macros_common.jinja   # → reduced to constants only
├── _macros_config.jinja   # → deleted (→ _modules/config.py)
├── _macros_desktop.jinja  # → deleted (→ _modules/desktop.py)
└── _macros_ipv6_tunnel.jinja # deleted or merged into _modules/service.py

tests/
├── test_host_features.py  # NEW
├── test_container.py      # NEW
├── test_service.py        # NEW
├── test_user_service.py   # NEW
├── test_installer.py      # NEW
├── test_pkg.py            # NEW
├── test_secrets.py        # NEW
├── test_config.py         # NEW
└── test_desktop.py        # NEW
```

**Deletion candidates**: `_macros_every.jinja` (already absent), `_macros_user.jinja`, `_macros_github.jinja`, `_macros_zsh.jinja` — referenced in plan template but not present in repo. Already clean.

---

## Phase 0: Research

### R0: Salt custom module API surface

**Decision**: Use Salt's standard extension points:
- `_modules/` for execution modules (callable as `salt['module.func']()`)
- `_states/` for custom state modules (callable as `mystate.managed`)
- Salt auto-loads these from `file_roots` on `saltutil.sync_all` or restart

**Rationale**: Salt has supported custom modules since version 0.9. Standard pattern.
**Alternatives**: Custom Jinja extensions, external CLI calls — rejected as more complex.

### R1: Custom state module return format

**Decision**: Return standard Salt state dict: `{'name': name, 'result': True, 'changes': {}, 'comment': ''}`. For multi-state output, return `{'name': name, 'result': True, 'changes': {}, 'comment': '', 'sub_state_run': [...]}` or use `__states__` dictionary to call other state modules.

**Rationale**: Salt 3006.x supports `__states__['file.managed'](...)` and `__states__['cmd.run'](...)` from within custom states.
**Alternatives**: Return YAML, use lowstate — rejected, too complex.

### R2: Jinja globals injection

**Decision**: Use Salt's `SLS_LODAER_GLOBALS` or a custom Jinja filter to inject shared variables (`user`, `home`, `retry_attempts`, etc.) into the template namespace before rendering.

**Rationale**: Salt's Jinja environment supports `env.globals.update(...)`. A custom module loaded at startup can populate these.
**Alternatives**: Keep `_macros_common.jinja` for constants only (no macros) — accepted as fallback.

### R3: lint-jinja.py mock adaptation

**Decision**: Extend `_MockSalt` class with stubs matching the new Python module API. When `lint-jinja.py` encounters `salt['host.feature_enabled'](...)`, it calls the same Python function since the mock imports it directly.

**Rationale**: The mock already imports `host_model.py` for feature resolution. Extending it to import the new modules is simpler than rewriting the mock.
**Alternatives**: Remove mock entirely — rejected, offline linting is a key feature.

---

## Phase 1: Design

### Data Model

Key data structures passed between Python modules and Jinja templates:

```yaml
entities:
  - name: HostConfig
    fields:
      - user: string  # from hosts.yaml
      - home: string  # from hosts.yaml
      - uid: int      # from hosts.yaml
      - features: dict  # resolved feature flags
      - runtime_dir: string  # XDG_RUNTIME_DIR
      - pkg_list: path  # installed package list location
  
  - name: ContainerSpec
    fields:
      - name: string  # catalog key
      - image: string  # full image ref with digest
      - scope: enum[system, user]
      - quadlet_source: string  # salt:// path
      - quadlet_path: string  # filesystem path
      - bind_mounts: list[BindMount]
      - manual_start: bool
      - healthcheck: HealthCheck | None
  
  - name: ServiceSpec
    fields:
      - name: string
      - unit_type: enum[service, timer, socket]
      - source: string  # salt:// path
      - enabled: bool | None
      - running: bool
      - template: string | None
      - context: dict
      - requires: list[string]
      - watch: list[string]
```

### Contracts

The Python modules expose these callable interfaces (identical to current macro signatures):

```python
# _modules/host_features.py
def feature_enabled(name: str) -> bool: ...
def feature_default(name: str) -> bool | None: ...

# _modules/service.py
def service_with_unit(name, source, unit_type='service', running=False, ...) -> dict: ...
def service_with_healthcheck(name, service, check_cmd=None, ...) -> dict: ...
def ensure_dir(name, path, mode=None, require=None, user=None) -> dict: ...
def remove_native_unit(name, unit_path=None, scope='system') -> dict: ...
def remove_native_package(name, pkgs) -> dict: ...
def ensure_running(name, service=None, watch=None) -> dict: ...
def service_stopped(name, svc, stop=True, requires=None, onlyif=None) -> dict: ...
def unit_override(name, service, source, filename='override.conf', requires=None) -> dict: ...
def managed_resource_value(value) -> str: ...
def managed_mode_value(mode) -> str: ...
def env_block() -> list[str]: ...
def render_service(name, opts, feature_flag, section_label, known_vars) -> dict: ...

# _modules/user_service.py
def user_service_file(name, filename, source=None, ...) -> dict: ...
def user_service_enable(name, services=None, start_now=None, ...) -> dict: ...
def user_service_with_unit(name, filename, source=None, ...) -> dict: ...
def user_service_restart(name, service, ...) -> dict: ...
def user_service_disable(name, units) -> dict: ...
def user_linger(name, user=None, require=None) -> dict: ...

# _modules/installer.py
def curl_bin(name, url, version=None, hash=None, ...) -> dict: ...
def cargo_pkg(name, pkg=None, bin=None, git=None, ...) -> dict: ...
def pip_pkg(name, pkg=None, bin=None, ...) -> dict: ...
def curl_extract_tar(name, url, binary_pattern=None, ...) -> dict: ...
def curl_extract_zip(name, url, binary_path=None, ...) -> dict: ...
def http_file(name, url, dest, mode='0644', ...) -> dict: ...
def git_clone_deploy(name, repo, dest, items=None, ...) -> dict: ...
def git_clone_build(name, repo_url, build_cmds, binary_src, ...) -> dict: ...
def download_font_zip(name, url, subdir, hash=None, ...) -> dict: ...
def github_release_to(state_id, name, repo, asset, dest, ...) -> dict: ...
def npm_build_workflow(name, dir, version=None, ...) -> dict: ...
def install_catalog(catalog, ver_dict, macro_type, exclude=None) -> dict: ...

# _modules/pkg.py
def paru_install(name, pkg, check=None, requires=None, version='') -> dict: ...
def simple_service(name, pkgs, service=None, check=None, requires=None) -> dict: ...
def pkgbuild_install(name, source, user=None, build_base='/tmp/pkgbuild', ...) -> dict: ...
def flatpak_install(app_id) -> dict: ...

# _modules/secrets.py
def gopass_secret(key, fallback_cmd='true', runas=None) -> str: ...
def proxypilot_key() -> str: ...
def tg_secret(gopass_key, cred_file, cred_base=None) -> str: ...

# _modules/config.py
def config_file_edit(name, cmd, unless=None, check_pattern=None, check_file=None, ...) -> dict: ...

# _modules/desktop.py
def browser_extensions(prefix, profile, extensions, user_js_id, unwanted=None) -> dict: ...
def hyprpm_update(name, check_plugins=None, require=None, timeout=300) -> dict: ...
def hyprpm_add(name, repo_url, check_plugin, require=None, timeout=300) -> dict: ...
def hyprpm_enable(name, plugin, require=None) -> dict: ...
def dconf_settings(name, settings, user=None, require=None) -> dict: ...

# _states/container.py
def managed(name, catalog_entry, image_registry, user_scope=False, requires=None, watch=None, quadlet_unit_name=None) -> dict: ...
```

---

## Status

Plan is ready for Phase 2 task generation (`/speckit.tasks`).
