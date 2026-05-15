---
name: spec
version: 1.0
description: "Feature specification: speed up full Salt state apply"

document:
  metadata:
    feature_name: "Accelerate Salt full-state apply"
    feature_branch: "080-speed-up-salt-apply"
    created: "2026-05-15"
    status: "Draft"
    input_description: >
      "как ускорить выкатку даже в том случае когда она проходит полностью"

  sections:
    - name: User Stories
      required: true
      items:
        - title: "Operator runs full apply and it completes faster"
          priority: P1
          description: >
            When the operator runs `just apply system_description` (or any full-state apply),
            the total wall-clock time is measurably lower than before. Independent states
            (no shared require chains) execute in parallel. Salt start-up overhead is minimized.
          why_priority: "Core request — this is the primary goal of the feature"
          independent_test: >
            Run `time just apply system_description` before and after changes.
            Compare total duration. Run `python3 scripts/state-profiler.py --trend` to
            verify individual state durations haven't regressed.
          acceptance_scenarios:
            - given: "a clean system (no changes since last successful apply)"
              when: "operator runs `just apply system_description`"
              then: "apply completes faster than before (measurable wall-clock reduction)"
            - given: "independent states with no shared require chains"
              when: "Salt processes them"
              then: "they execute in parallel, not sequentially"

        - title: "Auto mode still works and detects changes correctly"
          priority: P2
          description: >
            The existing `auto` mode (git-diff-based minimal rollout) continues to work.
            Optimizations don't break the impact planner.
          why_priority: "Auto mode is the primary daily workflow; must not regress"
          independent_test: >
            Make a change to a single state file, run `just apply`, verify only
            the affected state is applied.
          acceptance_scenarios:
            - given: "a change to one state file since last apply"
              when: "operator runs `just apply`"
              then: "only the affected state is applied, not the full tree"

        - title: "Slowest states are identified and individually optimized"
          priority: P3
          description: >
            The profiler reveals the top-N slowest states. Each slow state is inspected
            for redundant work (missing unless/creates guards), unnecessary sync points,
            or opportunities to cache/precompute.
          why_priority: "Targeted optimization yields highest ROI"
          independent_test: >
            Run `python3 scripts/state-profiler.py --trend --top 20` and verify
            the slowest states either have clear performance justification or guards.
          acceptance_scenarios:
            - given: "a profiling report"
              when: "slow states are inspected"
              then: "each has either a guard, a parallel flag, or documented justification"

    - name: Edge Cases
      required: true
      items:
        - scenario: "Parallel state conflict"
          description: >
            Two states marked parallel modify the same file or service. Salt may
            produce non-deterministic results. Must ensure parallel only applied
            to truly independent states.
        - scenario: "Daemon not available"
          description: >
            If the salt-daemon is not running, the apply falls back to direct salt-call.
            Optimizations must work in both modes.
        - scenario: "Network flapping during parallel downloads"
          description: >
            Parallel network operations may increase failure rate. Retry logic
            must handle concurrent failures gracefully.
        - scenario: "Test mode (--test)"
          description: >
            Apply with --test (dry-run) must still produce accurate results
            when parallel states are introduced.
        - scenario: "Failhard with parallel states"
          description: >
            If a parallel state fails with failhard: True, Salt must still
            stop dependent states correctly.

    - name: Functional Requirements
      required: true
      items:
        - id: FR-001
          description: >
            Salt states with no shared `require` chain execute in parallel
            (Salt `parallel: True` or batch-based scheduling)
          must: true
          clarification_needed: false
        - id: FR-002
          description: >
            `just apply system_description` wall-clock time is reduced by
            measurable amount through parallel execution of independent state groups
          must: true
          clarification_needed: false
        - id: FR-003
          description: >
            Existing guards (`unless`, `onlyif`, `creates`) are audited and
            strengthened to skip more states on re-applies
          must: true
          clarification_needed: false
        - id: FR-004
          description: >
            Salt daemon hot-reloads `_modules/` and `_states/` changes without
            restart, reducing start-up overhead on subsequent applies
          must: false
          clarification_needed: false
        - id: FR-005
          description: >
            `just lint` and `just validate` pass after all changes
          must: true
          clarification_needed: false
        - id: FR-006
          description: >
            Auto mode (`just apply` with git diff) still works correctly,
            impact planner identifies correct state subsets
          must: true
          clarification_needed: false
        - id: FR-007
          description: >
            Parallelism is gated by a feature flag or Salt config so it can be
            disabled without code changes
          must: false
          clarification_needed: false
        - id: FR-008
          description: >
            Group state files (`states/group/*.sls`) orchestrate parallel
            execution of their constituent states
          must: false
          clarification_needed: false

    - name: Key Entities
      required: false
      items:
        - name: "State execution plan"
          description: >
            Derived from the Salt state graph — identifies which states are independent
            (no shared require chain) and can execute concurrently
          relationships: "Built from require/onchanges/watch chains in .sls files"
        - name: "Parallel batch"
          description: >
            A set of states that execute concurrently. States within a batch share no
            `require` edges and modify non-overlapping resources.
          relationships: "Contains one or more Salt states"

    - name: Success Criteria
      required: true
      items:
        - id: SC-001
          metric: "Full apply wall-clock time reduced by at least 20% compared to baseline"
          type: performance
        - id: SC-002
          metric: "Auto mode still correctly narrows to changed files only (no regression)"
          type: quality
        - id: SC-003
          metric: "No increase in apply failure rate on repeated runs"
          type: quality
        - id: SC-004
          metric: "State profiler shows per-state durations unchanged or improved"
          type: performance
