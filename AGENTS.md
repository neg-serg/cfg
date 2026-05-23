# salt Development Guidelines

Auto-generated from active feature plans. Last updated: 2026-05-14

## Active Technologies
- Jinja2 + YAML Salt states, Python 3, Bash/Zsh helper scripts
- Salt 3008+ masterless workflow with Python execution modules (`_modules/`); upgraded from 3007.13
- Sphinx + MyST for embedded documentation; `just docs` builds static HTML site
- `just`, `ruff`, `shellcheck`, `yamllint`, `salt-lint`
- Repository artifacts under `states/`, `scripts/`, `docs/`, `.specify/`
- Markdown documentation, shell-based operator workflow, `gopass` 1.16.x + `age` + `age-plugin-yubikey`, `chezmoi`, systemd, Arch/CachyOS package management
- Zen Browser (`zen-browser-bin`), Surfingkeys, Hyprland/Wayfire launcher config, vicinae/dmenu/rofi

## Project Structure

```text
states/
scripts/
docs/
.specify/
└── templates/                # YAML templates for speckit workflow artifacts
    ├── spec-template.yaml
    ├── plan-template.yaml
    ├── tasks-template.yaml
    ├── constitution-template.yaml
    ├── checklist-template.yaml
    └── agent-file-template.yaml
```

## Mandatory Agent Requirements

- Any agent working in this repository must read and follow this file before making changes or taking repo actions.
- Do not add GitHub automation files, CI workflows, or `.github/workflows/` entries unless the user explicitly asks for them.

## Commands

- `just docs` — build the Sphinx + MyST documentation site to `docs/_build/html/`
- `just lint`
- `just validate`
- `just render-matrix`
- `python3 scripts/state-profiler.py --trend`
- `python3 scripts/state-profiler.py --compare <baseline> <candidate> --gate --min-sample-count 10`
- `SALT_PARALLEL=1 just apply system_description` — parallel group execution (independent groups run concurrently)
- `just apply system_description --parallel` — same, via CLI flag
- `python3 scripts/salt_parallel.py` — standalone parallel group executor

## Code Style

- Prefer explicit Salt/Jinja structure over meta-generated topology.
- All business logic lives in Python execution modules (`_modules/`), not Jinja macros.
- Preserve state ID readability and uniqueness across includes.
- Treat `states/**/*.sls` as the supported state tree for lint/render/index tooling.
- Use commit subjects in `[type] short description` format for local history, for example `[feat] ...`, `[fix] ...`, `[docs] ...`, or `[chore] ...`.

## Salt 3008 Features in Use

- `state_max_parallel: 8` — limits concurrent parallel states to prevent resource exhaustion
- `parallel: True` + `require` bug fixed (states no longer block each other) [#59959](https://github.com/saltstack/salt/issues/59959)
- Linear-time dependency resolution (was quadratic) — faster state compilation for 566-state applies [#59123](https://github.com/saltstack/salt/issues/59123)
- `file.managed` shows diff for new files in `test=True` mode [#65546](https://github.com/saltstack/salt/issues/65546)
- Native Python 3.13+ support (PEP 594 modules no longer need mocking; `salt_compat.py` simplified)
- `state.graph` / `state.graph_highstate` — built-in DOT dependency graph (replaces `scripts/dep-graph.py` for runtime)

## Salt 3008 Known Issues

- **`Function: unknown` + `unless`/`onlyif` ignored in highstate**: States generated via `@yaml_output` decorator show `function: unknown` and never evaluate `unless` or `onlyif` guards in the highstate context. Workaround: embed guard logic directly into shell commands with `exit 0` prefix (see `pkg.py`, `service.py`, `desktop.py` for pattern). Standalone `state.apply` on a single SLS file does NOT have this issue.

## Recent Changes
- Dynamic proxy switching for Zen Browser: Added menu script `switch-proxy` with Super+Alt+P binding for vicinae/dmenu/rofi selection, `set-zen-proxy` Python helper, integration with existing HTTP helper server (dynamic-proxy-switching)
- 079-age-yubikey-cutover: Added Markdown planning artifacts, Salt/Jinja states, shell-based operator workflow, `gopass` 1.16.1, `age` 1.3.1, `yubikey-manager` 5.9.0 + `gopass`, `age`, `age-plugin-yubikey`, `yubikey-manager`, `pcsclite` / `pcscd`, systemd user services, existing Salt data/state files, existing chezmoi templates


## LLM Entry Point

**Start by reading `docs/module-index.yaml`** — it's an auto-generated machine-readable YAML index of all project entities: states, macros, scripts, data files, tests, and documentation with their purposes, dependencies, feature gates, secrets, services, and config references. It provides a complete mental map of the project in a single file.

**Then read `docs/knowledge.yaml`** — the hand-authored machine-readable knowledge base containing all operational guides, recovery runbooks, standards, research analysis, and reference documentation in structured YAML format. Every entry cross-references entities in module-index.yaml.

**For a browsable HTML documentation site**, run `just docs` and open `docs/_build/html/index.html`. The site includes cross-referenced entity pages with hyperlinked relationships between states, macros, scripts, and data files.

**`docs/entity-manifest.yaml`** is an LLM-friendly stable entity index generated by `scripts/extract-inline-docs.py` — it lists all documented entities with their types, source paths, and purposes. LLM agents can load this manifest to quickly understand the project's entity landscape before making changes.

`docs/state-map.md` and `docs/data-inventory.md` are also auto-generated and provide complementary prose views (dependency graph, data file summaries).

The `.specify/templates/` directory contains YAML schema templates for the speckit workflow (spec, plan, tasks, constitution, checklist, agent-file). These define the canonical document structure for all feature artifacts.

<!-- MANUAL ADDITIONS START -->

- Do not add GitHub automation files unless the user explicitly asks for them.
- **No Russian documentation.** All documentation must be in English only. Do not create or maintain `.ru.md` files.
- **Auto-commit**: Commit every completed change immediately without asking. Use `[scope] description` format. Small atomic commits preferred over batching.
<!-- MANUAL ADDITIONS END -->

## Testing Strategy

- No unit tests. All validation is done via actual Salt state application.
- **`just validate`** — checks all 87 `.sls` files render without errors (fast, pre-apply)
- **VM‑based test environment**: QEMU + Arch Linux harness for full Salt deployment testing via `scripts/test-kvm-deploy.sh`, independent of the host's CachyOS rootfs.

<!-- FUTURE WORK -->
- **NixOS VM ↔ Salt cross‑validation**: Add automated CI that verifies the NixOS VM configuration stays equivalent to Salt states (package list diff, sysctl comparison, service parity).
<!-- END FUTURE WORK -->
