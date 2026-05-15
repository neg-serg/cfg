---
name: plan
version: 1.0
description: "Implementation plan: accelerate Salt full-state apply"

document:
  metadata:
    branch: "080-speed-up-salt-apply"
    date: "2026-05-15"
    spec_ref: ".specify/specs/080-speed-up-salt-apply/spec.yaml"
    input_description: "Speed up full Salt state rollout"

  sections:
    - name: Summary
      required: true
      description: |
        Reduce wall-clock time of `just apply system_description` (full-state apply)
        by introducing parallel execution of independent state groups, strengthening
        idempotency guards to skip more no-op states, and reducing Salt bootstrap overhead.
        
        Primary lever: parallel Salt state scheduling via `batch` mode or `parallel: True`
        for states with no shared `require` chains. Secondary levers: guard hardening,
        daemon hot-reload, group-level orchestration.

    - name: Technical Context
      required: true
      fields:
        language_version: "Python 3.14"
        primary_dependencies: "Salt 3006.x, Jinja2, Podman"
        storage: "YAML files (states/data/*.yaml), filesystem (mounts, dotfiles)"
        testing: "pytest, just validate, just lint, salt_contracts.py"
        target_platform: "CachyOS (Arch Linux), masterless Salt, zsh"
        project_type: "configuration management / infrastructure-as-code"
        performance_goals: "Full apply wall-clock ≤ 80% of current baseline"
        constraints: "Must not break auto mode (git-diff-based), must not increase failure rate"
        scale_scope: "Single host, ~80 Salt states across 40 .sls files"

    - name: Constitution Check
      required: true
      gates:
        - name: "I. Idempotency"
          passed: true
          notes: "Guard strengthening (FR-003) reinforces idempotency. Parallel execution does not create new unguarded states."
        - name: "II. Network Resilience"
          passed: true
          notes: "Parallel downloads use existing retry/interval macros. No reduction in resilience."
        - name: "III. Secrets Isolation"
          passed: false
          notes: "No secrets changes — not applicable to this optimization."
        - name: "IV. Macro-First"
          passed: true
          notes: "Parallel scheduling will be encoded in group states and/or macros, not inline."
        - name: "V. Minimal Change"
          passed: true
          notes: "Only necessary changes — guard additions, parallel flags, group orchestration. No speculative features."
        - name: "VI. Convention Adherence"
          passed: true
          notes: "State IDs preserved. Commit style maintained. No new file types introduced."
        - name: "VII. Verification Gate"
          passed: true
          notes: "`just lint`, `just validate`, and profiler MUST pass before considering done."

    - name: Project Structure
      required: true
      docs_layout:
        path: "specs/080-speed-up-salt-apply/"
        files:
          - name: "plan.yaml"
            type: "implementation plan"
          - name: "research.yaml"
            type: "Phase 0 research output"
          - name: "data-model.yaml"
            type: "Phase 1 data model"
          - name: "quickstart.yaml"
            type: "Phase 1 quickstart guide"
          - name: "contracts/"
            type: "Phase 1 contracts directory"
          - name: "tasks.yaml"
            type: "Phase 2 task list (created by speckit.tasks)"
      source_layout:
        description: "Existing Salt state tree — no new project structure"
        options: []
        selected: "Existing structure (states/, scripts/, tests/, docs/)"
        decision_rationale: "No new projects or services. Changes confined to existing Salt states, macros, and scripts."

    - name: Complexity Tracking
      required: false
      description: "No constitution violations requiring justification"
      items: []

# ── Phase 0: Research (to be expanded) ──────────────────────────────────────────

research:
  unknowns:
    - question: "Salt parallel: True vs batch mode — which is more appropriate for masterless?"
      status: NEEDS CLARIFICATION
      source: Technical Context
    - question: "Which states are truly independent (no shared require chain)?"
      status: NEEDS CLARIFICATION
      source: Technical Context
    - question: "What is the current full-apply wall-clock baseline?"
      status: NEEDS CLARIFICATION
      source: Technical Context
    - question: "Does Salt daemon hot-reload _modules/ changes without restart?"
      status: NEEDS CLARIFICATION
      source: FR-004
    - question: "Which states are the slowest and why (profiler analysis)?"
      status: NEEDS CLARIFICATION
      source: FR-003

# ── Phase 1: Design artifacts ───────────────────────────────────────────────────

design:
  approach: |
    Three-layered optimization:
    
    1. **State-level** (bottom): Strengthen idempotency guards on slow states.
       Add `unless:`/`creates:` to states that currently re-execute on every apply.
       Profile → identify worst offenders → add guards.
    
    2. **Group-level** (middle): Introduce parallel execution in group state files
       (`states/group/*.sls`). Groups call multiple independent .sls states and
       Salt can execute them in parallel via `batch` or `parallel: True`.
       Requires mapping require chains across state files to identify independent groups.
    
    3. **Infrastructure-level** (top): Reduce Salt bootstrap overhead.
       Ensure daemon hot-reloads _modules/. Optionally pre-warm cache.
       Parallelize bootstrapping steps where safe.
    
    The optimization is gated by a `SALT_PARALLEL` env var or `host.features.apply.parallel`
    flag so it can be disabled without code changes.

  parallel_strategy: |
    Group states (`states/group/*.sls`) are the natural parallelization boundary.
    Each group state includes multiple domain states. Domain states that share no
    require/watch chain can execute in parallel.
    
    Candidate independent groups (no cross-group require edges):
    - desktop (hyprland, niri, packages, portal, system, user)
    - network (dns, firewall, vpn_*, zapret2, proxy*)
    - services (ollama, jellyfin, transmission, vaultwarden, adguardhome, etc.)
    - ai_models (llama_embed, t5_summarization, image_generation, video_ai)
    - dotfiles (chezmoi — separate from Salt)
