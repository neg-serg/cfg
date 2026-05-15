---
name: quickstart
version: 1.0
description: "Quickstart: using accelerated Salt apply"

usage:
  full_apply:
    command: "just apply system_description"
    description: "Full state apply with parallel groups. Default: sequential. Set SALT_PARALLEL=1 for parallel."
    notes: "Env var SALT_PARALLEL=1 enables parallel group execution. host.features.apply.parallel: true in hosts.yaml makes it persistent."

  auto_mode:
    command: "just apply"
    description: "Auto mode (git-diff-based) — unchanged. Continues to use sequential single salt-call."
    notes: "Auto mode already minimal; parallelism adds no benefit since only changed states run."

  per_group:
    command: "just apply group/network"
    description: "Apply a single group — unchanged. No parallelism needed for single-group applies."

  profiling:
    commands:
      - "python3 scripts/state-profiler.py logs/system_description-*.log --top 30"
      - "python3 scripts/state-profiler.py --trend"
    description: "Profile state durations before and after changes to measure improvement."

feature_flag:
  env_var: "SALT_PARALLEL=1"
  host_yaml: "host.features.apply.parallel: true"
  default: false
  description: "When false (default), applies run sequentially as before. When true, independent groups run in parallel."

rollback:
  command: "SALT_PARALLEL=0 just apply system_description"
  description: "Disable parallelism for one run. Remove host.features.apply.parallel from hosts.yaml for permanent disable."
