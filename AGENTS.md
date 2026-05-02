# salt Development Guidelines

Auto-generated from active feature plans. Last updated: 2026-05-02

## Active Technologies
- Jinja2 + YAML Salt states, Python 3, Bash/Zsh helper scripts
- Salt 3006.x masterless workflow with shared `_macros_*.jinja`
- `just`, `pytest`, `ruff`, `shellcheck`, `yamllint`, `salt-lint`
- Repository artifacts under `states/`, `scripts/`, `tests/`, `docs/`, `specs/`
- Markdown documentation, shell-based operator workflow, `gopass` 1.16.x + `age` + `age-plugin-yubikey`, `chezmoi`, systemd, Arch/CachyOS package management
- Zen Browser (`zen-browser-bin`), Surfingkeys, Hyprland/Wayfire launcher config, vicinae/dmenu/rofi

## Project Structure

```text
states/
scripts/
tests/
docs/
specs/
```

## Mandatory Agent Requirements

- Any agent working in this repository must read and follow this file before making changes or taking repo actions.
- Do not add GitHub automation files, CI workflows, or `.github/workflows/` entries unless the user explicitly asks for them.

## Commands

- `just lint`
- `pytest tests/ -q`
- `just validate`
- `just render-matrix`
- `python3 scripts/state-profiler.py --trend`
- `python3 scripts/state-profiler.py --compare <baseline> <candidate> --gate --min-sample-count 10`

## Code Style

- Prefer explicit Salt/Jinja structure over meta-generated topology.
- Keep macros narrow and operationally transparent.
- Preserve state ID readability and uniqueness across includes.
- Treat `states/**/*.sls` as the supported state tree for lint/render/index tooling.
- Use commit subjects in `[type] short description` format for local history, for example `[feat] ...`, `[fix] ...`, `[docs] ...`, or `[chore] ...`.

## Recent Changes
- Dynamic proxy switching for Zen Browser: Added menu script `switch-proxy` with Super+Alt+P binding for vicinae/dmenu/rofi selection, `set-zen-proxy` Python helper, integration with existing HTTP helper server (dynamic-proxy-switching)
- 079-age-yubikey-cutover: Added Markdown planning artifacts, Salt/Jinja states, shell-based operator workflow, `gopass` 1.16.1, `age` 1.3.1, `yubikey-manager` 5.9.0 + `gopass`, `age`, `age-plugin-yubikey`, `yubikey-manager`, `pcsclite` / `pcscd`, systemd user services, existing Salt data/state files, existing chezmoi templates
- 078-gopass-age-research: Added Markdown, shell command evidence, `gopass` 1.16.1, `age`-backed store observations + `gopass`, `age`, GitHub upstream discussions/releases, local `gopass` configuration and CLI behavior, spec-kit artifacts
- 077-zen-browser-cutover: Added Jinja2 + YAML Salt states, Python 3 helper script, Markdown operator docs + Salt 3006.x masterless workflow, existing `_macros_*.jinja`, `zen-browser-bin`, Surfingkeys browser extension, systemd user services, Hyprland/Wayfire launcher config, spec-kit artifacts
- Russian documentation removal: Deleted 50 `.ru.md` files, removed `.ru.md` generation from `index-salt.py`, updated lint-docs, README, CLAUDE.md, constitution (`docs`/`cleanup`)
- Module index added: Auto-generated `docs/module-index.yaml` with full project map (79 states, 6 macros, 34+37 scripts, 36 data files, 33 tests, 49 docs); LLMs must read it first (`docs`/`tooling`)


## LLM Entry Point

**Start by reading `docs/module-index.yaml`** — it's an auto-generated machine-readable YAML index of all project entities: states, macros, scripts, data files, tests, and documentation with their purposes, dependencies, feature gates, secrets, services, and config references. It provides a complete mental map of the project in a single file.

`docs/state-map.md` and `docs/data-inventory.md` are also auto-generated and provide complementary prose views (dependency graph, data file summaries).

<!-- MANUAL ADDITIONS START -->
- `docs/superpowers/plans/*.md` are temporary working artifacts by default: do not commit them unless they are explicitly being kept as active shared planning documents. Remove stale plan files periodically once the related work is finished or abandoned.
- Do not add GitHub automation files unless the user explicitly asks for them.
- **No Russian documentation.** All documentation must be in English only. Do not create or maintain `.ru.md` files.
<!-- MANUAL ADDITIONS END -->

<!-- FUTURE WORK -->
- **VM‑based test environment**: Add a lightweight virtual‑machine harness (QEMU + Arch Linux) that can be used to test full Salt deployments of containerized services and other applications, independent of the host's CachyOS‑specific rootfs requirement. This would replace the current `scripts/vm‑smoke.sh` which expects a CachyOS rootfs.
<!-- END FUTURE WORK -->
