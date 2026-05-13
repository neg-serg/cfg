# Tasks: Jinja Macros → Python Modules

feature_name: "006-jinja-to-python"
input_refs: "specs/006-jinja-to-python/spec.md, specs/006-jinja-to-python/plan.md, specs/006-jinja-to-python/data-model.yaml, specs/006-jinja-to-python/research.yaml"
prerequisites: "plan.yaml (complete), spec.yaml (complete)"

conventions:
  task_format: "[ID] [P?] [Story?] Description with exact file paths"
  parallel_marker: "[P] = different files, no dependencies"
  story_marker: "[US1], [US2], [US3], [US4], [US5] = which user story"

phases:
  - name: Setup
    order: 1
    description: "Create directory structure and empty module files"
    purpose: "Shared infrastructure"
    tasks:
      - id: T001
        description: "Create states/_modules/__init__.py and states/_states/__init__.py"
        parallel: false
      - id: T002
        description: "Create states/_modules/common.py — shared constants (user, home, retry_attempts, ver_dir, download_cache, healthcheck_timeout, etc.) loaded from hosts.yaml"
        parallel: false
      - id: T003
        description: "Create states/_modules/data_loader.py — pre-load all states/data/*.yaml files into Jinja globals, inject HostConfig into template namespace"
        parallel: true
      - id: T004
        description: "Update scripts/lint-jinja.py _MockSalt — add delegation to new Python modules for salt['host.feature_enabled'], salt['container.deploy'], etc."
        parallel: true
      - id: T005
        description: "Update scripts/salt_source_model.py — add regex patterns for new salt['module.func']() calls alongside existing import_yaml patterns"
        parallel: true

  - name: Foundational
    order: 2
    description: "Core infrastructure blocking all user stories — shared constants and data loading"
    purpose: "CRITICAL: No user story work until this phase completes"
    tasks:
      - id: T006
        description: "Implement states/_modules/common.py — load hosts.yaml, extract user/home/uid/runtime_dir/pkg_list, provide get_host() function returning HostConfig dict"
        parallel: false
      - id: T007
        description: "Implement states/_modules/data_loader.py — load_all() reads every .yaml in states/data/, makes available as Jinja globals; replace _macros_common.jinja constant imports in _imports.jinja"
        parallel: true
      - id: T008
        description: "Implement tests/test_common.py — verify get_host() returns correct user/home/features from hosts.yaml + feature_registry.yaml"
        parallel: true
      - id: T009
        description: "Implement tests/test_data_loader.py — verify load_all() makes all 54 data files accessible, verify HostConfig structure"
        parallel: true
    checkpoint: "Foundation ready — shared constants and data loading available to all user stories"

  - name: User Story 1 — Feature Gating (P1)
    order: 3
    story_number: 1
    title: "Eliminate feature gating macros"
    priority: P1
    goal: "feature_enabled(name) and feature_default(name) move from _macros_registry.jinja to _modules/host_features.py"
    independent_test: "pytest tests/test_host_features.py; salt-call state.show_sls system_description --out=json and verify feature-gated states appear/disappear correctly"
    test_tasks:
      - id: T010
        description: "[P] [US1] Implement tests/test_host_features.py — test feature_enabled() for all 50+ features across all 9 matrix scenarios, test feature_default() returns correct registry values"
        parallel: true
        story: US1
    implementation_tasks:
      - id: T011
        description: "[US1] Implement states/_modules/host_features.py — feature_enabled(name): deep-traverse host.features dict; feature_default(name): deep-traverse registry.features + 'features' sub-dicts; load feature_registry.yaml on import"
        parallel: false
        story: US1
        depends_on: [T006]
      - id: T012
        description: "[US1] Update all .sls files — replace {% from '_macros_registry.jinja' import feature_enabled, feature_default %} with calls to salt['host.feature_enabled'](...)"
        parallel: false
        story: US1
        depends_on: [T011]
      - id: T013
        description: "[US1] Delete _macros_registry.jinja (or reduce to {% import_yaml 'data/feature_registry.yaml' as registry %} only if data_loader doesn't preload it)"
        parallel: false
        story: US1
        depends_on: [T012]
    checkpoint: "US1 complete — feature gating works via Python, all .sls files render, pytest passes"

  - name: User Story 2 — container_service (P1)
    order: 4
    story_number: 2
    title: "Eliminate container_service macro"
    priority: P1
    goal: "container_service() 165-line macro becomes _states/container.py custom state container.managed"
    independent_test: "pytest tests/test_container.py; salt-call state.show_sls ollama --out=json and diff state IDs against baseline"
    test_tasks:
      - id: T014
        description: "[P] [US2] Implement tests/test_container.py — test precondition failures (bad digest, scope mismatch, gpu violation), test correct state emission for system and user scopes, test localhost image skip pull, test bind_mount tilde expansion, test manual_start skip"
        parallel: true
        story: US2
    implementation_tasks:
      - id: T015
        description: "[US2] Implement states/_states/container.py — container.managed(name, catalog_entry, image_registry, user_scope=False, requires=None, watch=None, quadlet_unit_name=None): validate preconditions, resolve image reference, emit Quadlet file.managed + image pull + daemon-reload + enable + reset_failed + running + healthcheck via __states__ dict"
        parallel: false
        story: US2
        depends_on: [T006]
      - id: T016
        description: "[US2] Update all 14 containerized .sls files — replace container_service() macro calls with container.managed state"
        parallel: false
        story: US2
        depends_on: [T015]
      - id: T017
        description: "[US2] Delete _macros_container.jinja"
        parallel: false
        story: US2
        depends_on: [T016]
    checkpoint: "US2 complete — container deployment works via Python state, all containerized services render identically"

  - name: User Story 3 — Service Management (P1)
    order: 5
    story_number: 3
    title: "Eliminate service management macros"
    priority: P1
    goal: "All service lifecycle macros move to _modules/service.py and _modules/user_service.py"
    independent_test: "pytest tests/test_service.py tests/test_user_service.py; render any service .sls and compare state IDs"
    test_tasks:
      - id: T018
        description: "[P] [US3] Implement tests/test_service.py — test service_with_unit, service_with_healthcheck, ensure_dir, remove_native_unit, remove_native_package, ensure_running, service_stopped, unit_override, managed_resource_value, env_block, render_service"
        parallel: true
        story: US3
      - id: T019
        description: "[P] [US3] Implement tests/test_user_service.py — test user_service_file, user_service_enable, user_service_with_unit, user_service_restart, user_service_disable, user_linger"
        parallel: true
        story: US3
    implementation_tasks:
      - id: T020
        description: "[US3] Implement states/_modules/service.py — all system-scoped service lifecycle functions: service_with_unit(), service_with_healthcheck(), ensure_dir(), remove_native_unit(), remove_native_package(), ensure_running(), service_stopped(), unit_override(), managed_resource_value(), managed_mode_value(), env_block(), render_service(). Each returns dict matching current macro output"
        parallel: false
        story: US3
        depends_on: [T006]
      - id: T021
        description: "[P] [US3] Implement states/_modules/user_service.py — all user-scoped service lifecycle functions: user_service_file(), user_service_enable(), user_service_with_unit(), user_service_restart(), user_service_disable(), user_linger(). Each returns dict matching current macro output"
        parallel: true
        story: US3
        depends_on: [T006]
      - id: T022
        description: "[US3] Update all .sls files — replace service macro calls with salt['service.*']() and salt['user_service.*']()"
        parallel: false
        story: US3
        depends_on: [T020, T021]
      - id: T023
        description: "[US3] Reduce _macros_service.jinja to constants only (delete all macro definitions); delete _macros_service_user.jinja"
        parallel: false
        story: US3
        depends_on: [T022]
    checkpoint: "US3 complete — all service lifecycle managed via Python modules"

  - name: User Story 4 — Installer Macros (P2)
    order: 6
    story_number: 4
    title: "Eliminate installer macros"
    priority: P2
    goal: "All 12 installer macros move to _modules/installer.py"
    independent_test: "pytest tests/test_installer.py; render installers.sls and installers_desktop.sls, compare state IDs"
    test_tasks:
      - id: T024
        description: "[P] [US4] Implement tests/test_installer.py — test curl_bin, cargo_pkg, pip_pkg, curl_extract_tar (with fetch_tag, strip_v, dest variants), curl_extract_zip, http_file, git_clone_deploy, git_clone_build, download_font_zip, github_release_to, npm_build_workflow, install_catalog"
        parallel: true
        story: US4
    implementation_tasks:
      - id: T025
        description: "[US4] Implement states/_modules/installer.py — all installer functions: curl_bin(), cargo_pkg(), pip_pkg(), curl_extract_tar(), curl_extract_zip(), http_file(), git_clone_deploy(), git_clone_build(), download_font_zip(), github_release_to(), npm_build_workflow(), install_catalog(). Use salt['cmd.run_all']() for gopass probing in gopass_secret context if needed"
        parallel: false
        story: US4
        depends_on: [T006]
      - id: T026
        description: "[US4] Update installers.sls, installers_desktop.sls, and any other .sls using installer macros — replace with salt['installer.*']() calls"
        parallel: false
        story: US4
        depends_on: [T025]
      - id: T027
        description: "[US4] Delete _macros_install.jinja"
        parallel: false
        story: US4
        depends_on: [T026]
    checkpoint: "US4 complete — all installers work via Python"

  - name: User Story 5 — Remaining Macros (P3)
    order: 7
    story_number: 5
    title: "Eliminate remaining macros (packages, secrets, config, desktop, ipv6_tunnel)"
    priority: P3
    goal: "All tail macros move to respective Python modules, zero macro definitions remain in _macros_*.jinja"
    independent_test: "just render-matrix passes all 9 scenarios; grep -r '{% macro' states/_macros_*.jinja returns nothing"
    test_tasks:
      - id: T028
        description: "[P] [US5] Implement tests/test_pkg.py — test paru_install, simple_service, pkgbuild_install, flatpak_install"
        parallel: true
        story: US5
      - id: T029
        description: "[P] [US5] Implement tests/test_secrets.py — test gopass_secret (with caching, fallback, daemon detection), proxypilot_key, tg_secret"
        parallel: true
        story: US5
      - id: T030
        description: "[P] [US5] Implement tests/test_config.py — test config_file_edit with auto-guard, onlyif, retry variants"
        parallel: true
        story: US5
      - id: T031
        description: "[P] [US5] Implement tests/test_desktop.py — test browser_extensions, hyprpm_update/add/enable, dconf_settings"
        parallel: true
        story: US5
    implementation_tasks:
      - id: T032
        description: "[US5] Implement states/_modules/pkg.py — paru_install(), simple_service(), pkgbuild_install(), flatpak_install(). pkgbuild_install must handle replace_check, conflicts, extra_sources"
        parallel: true
        story: US5
        depends_on: [T006]
      - id: T033
        description: "[P] [US5] Implement states/_modules/secrets.py — gopass_secret() with namespace-based caching (use module-level dict to replicate Jinja namespace behavior), proxypilot_key(), tg_secret()"
        parallel: true
        story: US5
        depends_on: [T006]
      - id: T034
        description: "[P] [US5] Implement states/_modules/config.py — config_file_edit() with auto-guard generation (unless from check_pattern/check_file), onlyif, retry, shell"
        parallel: true
        story: US5
        depends_on: [T006]
      - id: T035
        description: "[P] [US5] Implement states/_modules/desktop.py — browser_extensions(), hyprpm_update(), hyprpm_add(), hyprpm_enable(), dconf_settings()"
        parallel: true
        story: US5
        depends_on: [T006]
      - id: T036
        description: "[US5] Move ipv6_tunnel() macro logic to states/_modules/service.py or create states/_modules/network.py"
        parallel: false
        story: US5
        depends_on: [T020]
      - id: T037
        description: "[US5] Update all remaining .sls files — replace pkg/secrets/config/desktop/ipv6 macro calls with salt['pkg.*'](), salt['secrets.*'](), salt['config.*'](), salt['desktop.*']()"
        parallel: false
        story: US5
        depends_on: [T032, T033, T034, T035, T036]
      - id: T038
        description: "[US5] Clean up _macros_*.jinja — delete _macros_pkg.jinja, _macros_config.jinja, _macros_desktop.jinja, _macros_ipv6_tunnel.jinja; reduce _macros_common.jinja to {% import_yaml %} + {% set %} constants only (no macro definitions); verify `grep -r '{% macro' states/_macros_*.jinja` returns nothing"
        parallel: false
        story: US5
        depends_on: [T037]
    checkpoint: "US5 complete — zero macro definitions remain, all .sls files use Python modules"

  - name: Polish
    order: 99
    description: "Cross-cutting cleanup and verification"
    purpose: "Final verification that migration is complete and correct"
    tasks:
      - id: T039
        description: "Run just render-matrix and fix any remaining template errors — ensure all 9 scenarios pass"
        parallel: false
      - id: T040
        description: "Run just lint and ensure no new violations introduced"
        parallel: true
      - id: T041
        description: "Run pytest tests/ -q and ensure all new tests pass"
        parallel: true
      - id: T042
        description: "Run just validate (salt-validate.sh) and salt_contracts.py to verify contracts still pass"
        parallel: true
      - id: T043
        description: "Verify salt_impact.py correctly resolves data→state dependencies for migrated states"
        parallel: true
      - id: T044
        description: "Update _imports.jinja to use data_loader globals instead of _macros_common imports"
        parallel: false
      - id: T045
        description: "Update scripts/index-salt.py rendering pipeline to handle new salt['module.func']() patterns"
        parallel: false
      - id: T046
        description: "Regenerate docs/module-index.yaml and docs/knowledge.yaml via index-salt.py"
        parallel: false
      - id: T047
        description: "Amend constitution Principle IV (Macro-First) to reflect Python modules as preferred mechanism"
        parallel: true

dependencies:
  phase_dependencies:
    - phase: Setup
      depends_on: []
    - phase: Foundational
      depends_on: [Setup]
      blocks: ["all user stories"]
    - phase: "User Story 1 (Feature Gating)"
      depends_on: [Foundational]
    - phase: "User Story 2 (container_service)"
      depends_on: [Foundational]
    - phase: "User Story 3 (Service Management)"
      depends_on: [Foundational]
    - phase: "User Story 4 (Installer Macros)"
      depends_on: [Foundational]
    - phase: "User Story 5 (Remaining Macros)"
      depends_on: [Foundational, "User Story 3"]
    - phase: Polish
      depends_on: ["all user stories complete"]
  story_dependencies:
    - story: US1
      depends_on: [Foundational]
      independent: true
    - story: US2
      depends_on: [Foundational]
      independent: true
    - story: US3
      depends_on: [Foundational]
      independent: true
    - story: US4
      depends_on: [Foundational]
      independent: true
    - story: US5
      depends_on: [Foundational, US3]
      independent: false
      reason: "ipv6_tunnel macro depends on service_with_unit from US3"

strategy:
  mvp_first:
    - "Complete Phase 1: Setup"
    - "Complete Phase 2: Foundational (common.py + data_loader.py)"
    - "Complete US1 (feature gating) — most impactful single change"
    - "STOP and VALIDATE: pytest + render-matrix"
  incremental_delivery:
    - "Setup + Foundational → shared infrastructure"
    - "US1 → feature gating in Python (testable independently)"
    - "US2 → container deployment in Python (testable independently)"
    - "US3 → service management in Python (testable independently)"
    - "US4 → installers in Python (testable independently)"
    - "US5 → remaining macros + cleanup (depends on US3 for ipv6_tunnel)"
    - "Polish → final verification + constitution amendment"
