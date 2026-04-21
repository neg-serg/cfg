# Salt Explainability

This repository keeps `states/**/*.sls` as the primary execution contract, but now also exposes an explainability layer around those states.

The goal of the explainability layer is simple: answer questions like these without manual grep-heavy debugging:

- Why does this state exist?
- Which state owns this state ID?
- Which YAML inventory file feeds this state?
- Which states import this data file?
- Which macro is likely used by this state?

## Source Of Truth

The explainability tooling is intentionally layered on top of explicit Salt, not instead of it.

What remains source of truth:

- `states/**/*.sls`
  The executable Salt tree.
- `states/system_description.sls`
  The explicit top-level orchestration map.
- `states/host_config.jinja`
  The runtime host configuration authority.
- `states/data/*.yaml`
  Structured inventories and declarative inputs.

What is derived:

- `scripts/salt_source_model.py`
  Canonical discovery and source metadata extraction.
- `scripts/index-salt.py`
  Rendered state IDs, include relationships, and generated indexes.
- `scripts/render-matrix.py`
  Scenario-based render validation and JSON result rows.
- `scripts/dep-graph.py`
  Include/requisite graph output in text, dot, svg, and json.
- `scripts/salt_provenance.py`
  Reverse lookups across states, state IDs, YAML files, data keys, and macros.

The rule is: derived tooling may explain the tree, but it does not replace the tree.

## Why `system_description.sls` Stays Explicit

`states/system_description.sls` is intentionally not generated.

It is the human-readable topology of the host build and remains the fastest way to understand broad orchestration order and major feature gates. The explainability layer complements it by answering finer-grained questions, but it does not hide the top-level state graph behind another DSL.

## Shared Discovery Model

The explainability layer starts with `scripts/salt_source_model.py`.

It provides canonical recursive state discovery and source metadata for all `states/**/*.sls`, including:

- canonical dotted `state_name`
- repo-relative `relpath`
- `top_level_entrypoint`
- `workflow_apply_target`
- imported YAML files
- feature guards inferred from conditional Jinja expressions

This shared model is reused by the current explainability scripts so they stop inventing separate notions of what the state tree looks like.

## Provenance Queries

Use `scripts/salt_provenance.py` to query the reverse index.

Supported lookups:

```bash
.venv/bin/python3 scripts/salt_provenance.py --state services
.venv/bin/python3 scripts/salt_provenance.py --state-id unbound_restart_or_reload
.venv/bin/python3 scripts/salt_provenance.py --data-file states/data/service_catalog.yaml
.venv/bin/python3 scripts/salt_provenance.py --data-key service_catalog.loki
.venv/bin/python3 scripts/salt_provenance.py --macro ensure_dir
```

JSON output is available for every lookup mode:

```bash
.venv/bin/python3 scripts/salt_provenance.py --state services --json
```

Convenience recipes:

```bash
just provenance services
just provenance-id unbound_restart_or_reload
```

## What The Provenance Layer Can Answer Today

Current lookups are intentionally practical rather than perfect.

`--state`
- Returns the owning state file, entrypoint flags, imported YAML files, includes, state IDs, and feature guards.

`--state-id`
- Returns the owning state or states for a rendered Salt state ID.

`--data-file`
- Returns states that import or otherwise consume a given YAML file.

`--data-key`
- Tries to prefer source-level matches such as `catalog.loki` over coarse file-level ownership.
- Falls back safely to file-level consumers when precise matching is not available.

`--macro`
- Returns states that appear to call a real macro defined in `states/_macros_*.jinja`.
- Macro lookup is restricted to actually defined macros, so ordinary method calls like `get(...)` or `items(...)` are not treated as provenance macros.

## Limits Of The Current Provenance Layer

The current implementation is useful, but it is still heuristic in some places.

- `--data-key` is precise only when the state source clearly references the imported alias and key path.
- Macro lookup is definition-driven, but still source-based rather than fully Jinja-AST-aware.
- Requisite provenance is still relatively shallow compared to full state graph semantics.

That is acceptable at this stage because the purpose of the layer is to improve everyday debugging and navigation first, then deepen precision over time.

## Related Tools

The explainability layer is broader than provenance alone.

Useful adjacent commands:

```bash
.venv/bin/python3 scripts/render-matrix.py --json
.venv/bin/python3 scripts/dep-graph.py --format json
VALIDATE_SUMMARY_FILE=/tmp/validate-summary.json scripts/salt-validate.sh
```

These outputs are designed to be machine-readable without replacing the existing human-facing CLI output.

## Design Intent

The repository is moving toward an explainable Salt system, not a generated Salt system.

That means:

- explicit topology remains visible
- inventories remain plain YAML
- state files remain reviewable artifacts
- tooling adds traceability and reverse lookup capability
- new abstraction is justified only when it improves observability, not just DRY

This is the core constraint behind the current refactor work.
