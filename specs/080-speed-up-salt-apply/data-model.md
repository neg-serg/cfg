---
name: data-model
version: 1.0
description: "Phase 1 data model: parallel apply orchestration"

entities:
  - name: ApplyPhase
    description: "A group of Salt states executed as a single salt-call process"
    fields:
      - name: name
        type: string
        description: "Phase identifier (core, packages, desktop, network, services, ai)"
      - name: states
        type: list[string]
        description: "Salt state names to apply in this phase"
      - name: depends_on
        type: list[string]
        description: "Phases that must complete before this phase"
      - name: parallel_with
        type: list[string]
        description: "Phases that can run concurrently with this phase"
      - name: timeout
        type: int
        description: "Max wall-clock seconds for this phase"
        optional: true

  - name: ApplyResult
    description: "Result of a single phase execution"
    fields:
      - name: phase_name
        type: string
      - name: exit_code
        type: int
      - name: duration_ms
        type: int
      - name: log_file
        type: string
        description: "Path to phase-specific log file"

  - name: ParallelGate
    description: "Feature flag controlling parallel execution"
    fields:
      - name: enabled
        type: boolean
        description: "host.features.apply.parallel or SALT_PARALLEL env var"
      - name: max_parallel
        type: int
        description: "Maximum concurrent salt-call processes"
        default: 4
