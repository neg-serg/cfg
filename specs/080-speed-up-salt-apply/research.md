---
name: research
version: 1.0
description: "Phase 0 research: Salt parallelism and apply optimization"

decisions:
  - topic: "Salt parallel execution in masterless mode"
    decision: "Use multiprocess salt-call for independent state groups"
    rationale: >
      Salt's `parallel: True` on `cmd.run` only works within a single state file
      and is limited to cmd.run/cmd.script states. Cross-state parallelism requires
      running multiple salt-call processes concurrently. The natural parallelization
      boundary is group state files (`states/group/*.sls`), not individual states.
      
      Salt's `--batch` flag is for master-minion topology and doesn't apply to
      masterless single-host deployments.
    alternatives_considered:
      - "Salt batch mode": "Not available in masterless. Rejected."
      - "parallel: True on individual states": "Limited to cmd.run within one file. Insufficient scope."
      - "Rewrite in Ansible": "Violates constitution (existing Salt investment). Rejected."

  - topic: "Current apply wall-clock baseline"
    decision: "Use profiler-driven measurement — no manual timing needed"
    rationale: >
      The state profiler already captures per-state durations from logs.
      Full-apply baseline will be measured from the most recent full
      system_description apply log. The profiler's --trend mode tracks
      per-state duration statistics across all logs.
    alternatives_considered: []

  - topic: "Independent state groups"
    decision: "Six groups (core, packages, desktop, network, services, ai) are largely independent"
    rationale: >
      Analysis of group state files shows:
      - core: mounts, cachyos, system — requires nothing from other groups
      - packages: pacman installs — independent of runtime config
      - desktop: audio, fonts, compositor — requires packages group (packages must be installed)
      - network: dns, vpn, firewall — requires packages group
      - services: systemd services — requires packages, depends on network for some
      - ai: LLM models, containers — requires packages, services (containers need podman)
      
      Core + Packages run first. Desktop/Network run in parallel after packages.
      Services runs after Network. AI runs after Services.
      
      Within each group, states are sequential (Salt's include mechanism is sequential).
    alternatives_considered:
      - "Per-state parallelism": "Too granular — require chains would serialize most work."
      - "No groups at all (flat apply)": "Already the current behavior. No speedup."

  - topic: "Daemon hot-reload"
    decision: "Daemon already handles _modules/ hot-reload"
    rationale: >
      Recent commits (5445369b, f9f7d54c) already ensure _modules/ changes are picked up
      without daemon restart. The daemon inserts source _modules/ before cached copies.
      No additional work needed for FR-004.
    alternatives_considered: []

  - topic: "Salt bootstrap overhead reduction"
    decision: "Keep existing bootstrap as-is; it's amortized over daemon lifetime"
    rationale: >
      The bootstrap phase (venv check, config generation, daemon start) runs once
      before every apply. It takes ~1-2 seconds and is negligible compared to
      package install times. The daemon persists between applies, so subsequent
      applies skip the bootstrap entirely.
    alternatives_considered:
      - "Pre-warm venv": "Already done — salt-daemon keeps venv loaded."
      - "Inline runtime config": "Config is already generated once. No gain from precomputing."

  - topic: "Guard hardening — slowest states"
    decision: "Audit top slow states for missing guards; add only where safe"
    rationale: >
      Without readable full-apply logs, guard audit will use code inspection.
      Package install states (via _macros_pkg.jinja) already have pacman-based
      guards. File downloads (via _macros_install.jinja) already have `creates:`.
      Container builds (`cmd.script`) have `creates:`.
      
      Potential gap: `locale-gen` in system_description.sls has no guard.
      `cmd.run` states in some inline configs may lack guards.
    alternatives_considered: []

  - topic: "Feature gate for parallel mode"
    decision: "Use host.yaml feature flag + env var override"
    rationale: >
      Parallel execution will be gated by `host.features.apply.parallel` (default: false).
      Can be overridden with `SALT_PARALLEL=1` env var for ad-hoc testing.
      This allows gradual rollout and easy rollback.
    alternatives_considered:
      - "Env var only": "No persistent config. Rejected."
      - "Always parallel": "Too aggressive for initial deployment. Rejected."

parallel_execution_plan:
  approach: "Multiprocess salt-call for independent groups"
  phases:
    - phase: 1
      description: "Baseline + guard hardening"
      steps:
        - "Profile current full-apply duration"
        - "Add guards to unguarded states (locale-gen, systemd-tmpfiles, etc.)"
        - "Verify no regression via just validate + pytest"
    
    - phase: 2
      description: "Group-level parallelism"
      steps:
        - "Add parallel orchestration to system_description.sls: run core→packages first, then desktop∥network∥services∥ai"
        - "Implement in salt-apply.sh: detect parallel flag, spawn salt-call per group"
        - "Collect exit codes, show per-group summaries"
    
    - phase: 3
      description: "Optimize the slowest individual states"
      steps:
        - "Parallel downloads within states (add parallel: True to independent cmd.run states)"
        - "Local cache warming for frequently-downloaded assets"

group_dependency_map:
  groups:
    - name: core
      states: [mounts, cachyos, system_description]
      depends_on: []
      parallel_with: []

    - name: packages
      states: [installers_base, installers_desktop, installers_themes, custom_pkgs]
      depends_on: [core]
      parallel_with: []

    - name: desktop
      states: [audio, fonts, desktop, greetd, pacman_db_warmup]
      depends_on: [packages]
      parallel_with: [network]

    - name: network
      states: [dns, network, ipv6*, amnezia*, zapret2*, hiddify*]
      depends_on: [packages]
      parallel_with: [desktop]

    - name: services
      states: [services, monitoring_alerts, user_services, jellyfin*, transmission*, etc.]
      depends_on: [network]
      parallel_with: [ai]

    - name: ai
      states: [ollama, llama_embed, image_generation, video_ai, t5_summarization, telethon_bridge*, etc.]
      depends_on: [services]
      parallel_with: [services]
