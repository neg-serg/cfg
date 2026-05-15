---
name: tasks
version: 1.0
description: "Task list for accelerating Salt full-state apply"

document:
  metadata:
    feature_name: "080-speed-up-salt-apply"
    input_refs: "specs/080-speed-up-salt-apply/plan.yaml, specs/080-speed-up-salt-apply/spec.yaml, specs/080-speed-up-salt-apply/research.yaml"
    prerequisites: "plan.yaml (required), spec.yaml (required for user stories), research.yaml (decisions)"

  conventions:
    task_format: "[P?] [Story] Description with exact file paths"
    parallel_marker: "[P] = different files, no dependencies"
    story_marker: "[US1], [US2], [US3] = which user story"

  phases:
    - name: Setup
      order: 1
      description: "Project initialization and basic structure"
      purpose: "Shared infrastructure"
      tasks:
        - id: T001
          description: "Create feature branch 080-speed-up-salt-apply with spec, plan, research, data-model, quickstart artifacts in specs/080-speed-up-salt-apply/"
          parallel: false
        - id: T002
          description: "Add `apply.parallel` feature flag to states/data/hosts.yaml under features.apply section"
          parallel: false
        - id: T003
          description: "Add `SALT_PARALLEL` env var override in scripts/salt-apply.sh bootstrap section"
          parallel: false

    - name: Foundational
      order: 2
      description: "Guard hardening and baseline measurement"
      purpose: "CRITICAL: No user story work until this phase completes"
      tasks:
        - id: T004
          description: "Run `just apply system_description` and capture baseline wall-clock time. Log duration in docs/ as apply-performance-baseline.md"
          parallel: false
        - id: T005
          description: "Run `python3 scripts/state-profiler.py --trend --top 30` and log top slowest states in docs/apply-performance-baseline.md"
          parallel: false
        - id: T006
          description: "Add `destroys`/`unless` guard to `system_locale_generate` (locale-gen) in states/system_description.sls"
          parallel: false
        - id: T007
          description: "Audit all inline `cmd.run` states in states/*.sls for missing idempotency guards (unless/onlyif/creates) and add where safe"
          parallel: false
        - id: T008
          description: "Remove `locale-gen` from unguarded cmd.run — verify system_locale_generate in states/system_description.sls has proper guard"
          parallel: false
      checkpoint: "Foundation ready — all states have idempotency guards. Baseline measured. User story implementation can now begin."

    - name: User Story
      order_start: 3
      max_repeats: 10
      items:
        - story_number: 1
          title: "Parallel group execution"
          priority: P1
          goal: "Independent state groups (core, packages, desktop, network, services, ai) execute in parallel via multiprocess salt-call"
          independent_test: >
            Set SALT_PARALLEL=1, run `just apply system_description`. Verify that
            network and desktop groups run concurrently (their start times overlap in log).
            Verify total wall-clock is less than sum of sequential group durations.
          test_tasks: []
          implementation_tasks:
            - id: T009
              description: "Implement phase orchestration in scripts/salt-apply.sh: detect SALT_PARALLEL or host.features.apply.parallel, resolve group dependency graph, spawn parallel salt-call processes for independent groups"
              parallel: true
              story: US1
            - id: T010
              description: "Create scripts/salt_parallel.py — helper that resolves group graph (core→packages→{desktop∥network}→{services∥ai}), manages concurrent salt-call subprocesses, and aggregates exit codes"
              parallel: true
              story: US1
            - id: T011
              description: "Add per-phase log files in logs/ (e.g. logs/phase-core-*.log, logs/phase-network-*.log) and summary output showing each phase's exit code and duration"
              parallel: false
              story: US1
            - id: T012
              description: "Update group dependency map in scripts/salt_parallel.py with actual require chains: core (no deps), packages (core), desktop (packages), network (packages), services (network), ai (services)"
              parallel: false
              depends_on: [T010]
              story: US1
            - id: T013
              description: "Add `--parallel` flag to salt-apply.sh (aliases `just apply --parallel system_description`) that enables parallel mode for one run without env var"
              parallel: true
              story: US1
            - id: T014
              description: "Add error handling: if any parallel phase fails, kill remaining in-progress phases and show aggregated failure summary with pointers to phase logs"
              parallel: false
              depends_on: [T009, T010]
              story: US1
          checkpoint: "US1 should be fully functional — independent groups run in parallel with SALT_PARALLEL=1, total apply time is measurably reduced"

        - story_number: 2
          title: "Auto mode regression check"
          priority: P2
          goal: "Auto mode (git-diff-based minimal rollout) continues to work correctly with parallel changes"
          independent_test: >
            Make a small change to one state file (e.g. add a comment to audio.sls).
            Run `just apply` (auto mode). Verify only the affected state(s) are applied
            and parallel flag does not change the behavior.
          test_tasks: []
          implementation_tasks:
            - id: T015
              description: "Ensure salt_impact.py mapping is unchanged — auto mode skips salt_parallel.py entirely when SALT_PARALLEL is not set or group count is 1"
              parallel: true
              story: US2
            - id: T016
              description: "Test: modify states/audio.sls, run `just apply`, verify only audio/logs appear and no parallel group execution occurs"
              parallel: false
              depends_on: [T015]
              story: US2
            - id: T017
              description: "Test: run `SALT_PARALLEL=1 just apply` (auto mode with parallel flag), verify it falls back to sequential since auto mode produces single-state targets"
              parallel: false
              depends_on: [T015]
              story: US2
          checkpoint: "Auto mode unchanged — both with and without SALT_PARALLEL"

        - story_number: 3
          title: "Slow state optimization"
          priority: P3
          goal: "Identify and optimize the slowest individual states in the profiler output"
          independent_test: >
            Run `python3 scripts/state-profiler.py --trend`. Verify top-10 slowest states
            have either: (a) proper idempotency guard, (b) parallel: True for independent
            cmd.run, or (c) documented reason for being slow.
          test_tasks: []
          implementation_tasks:
            - id: T018
              description: "Run profiler, identify top-5 slowest states from logs/*.log, document in docs/slow-state-audit.md"
              parallel: true
              story: US3
            - id: T019
              description: "For each slow state: add `parallel: True` to cmd.run if state is independent (no shared require chain) and performs network or CPU work"
              parallel: true
              story: US3
            - id: T020
              description: "Add `retry` block to any slow network-facing state that lacks it per Network Resilience constitution rule"
              parallel: true
              story: US3
            - id: T021
              description: "For container image pulls in states/*.sls: verify `unless: podman image exists` is present on all pull states to skip on re-apply"
              parallel: true
              story: US3
            - id: T022
              description: "Re-profile post-optimizations, update docs/slow-state-audit.md with before/after durations"
              parallel: false
              depends_on: [T018, T019, T020, T021]
              story: US3
          checkpoint: "US3 complete — top slow states optimized, profiler shows measurable improvement"

    - name: Polish
      order: 99
      description: "Cross-cutting improvements"
      purpose: "Improvements affecting multiple user stories"
      tasks:
        - id: T023
          description: "Run `just lint` and `just validate` — fix any issues"
          parallel: true
        - id: T024
          description: "Run full apply in both sequential (default) and parallel (SALT_PARALLEL=1) mode, confirm both pass cleanly"
          parallel: false
        - id: T025
          description: "Update AGENTS.md Commands section if new CLI flags (--parallel) were added"
          parallel: true
        - id: T026
          description: "Update docs/module-index.yaml if any new scripts or states were added"
          parallel: true
        - id: T027
          description: "Commit all changes and verify branch is ready for merge to main"
          parallel: false

  dependencies:
    phase_dependencies:
      - phase: "Setup"
        depends_on: []
      - phase: "Foundational"
        depends_on: ["Setup"]
        blocks: ["all user stories"]
      - phase: "User Stories"
        depends_on: ["Foundational"]
      - phase: "Polish"
        depends_on: ["all desired user stories complete"]
    story_dependencies:
      - story: "US1 — Parallel groups (P1)"
        depends_on: ["Foundational"]
        independent: true
      - story: "US2 — Auto mode regression (P2)"
        depends_on: ["Foundational"]
        may_integrate_with: ["US1"]
        independent: true
      - story: "US3 — Slow state optimization (P3)"
        depends_on: ["Foundational"]
        may_integrate_with: ["US1", "US2"]
        independent: true
    within_story_order:
      - "Core infrastructure before per-story work"
      - "Baseline measurement before optimization"
      - "Guard hardening before parallel execution"

  strategy:
    mvp_first:
      - "Complete Phase 1: Setup (T001-T003)"
      - "Complete Phase 2: Foundational — guards + baseline (T004-T008)"
      - "Complete US1 (P1) — parallel group execution"
      - "STOP and VALIDATE: run full apply with SALT_PARALLEL=1, measure wall-clock reduction"
    incremental_delivery:
      - "Setup + Foundational => all states guarded, baseline known"
      - "Add US1 (parallel groups) => test with full apply (MVP)"
      - "Add US2 (auto mode regression check) => verify no regression"
      - "Add US3 (slow state optimization) => profile-driven optimization"
