# Salt 3008+ Upgrade Guide with Git Worktrees

**Date**: 2026-04-18  
**Status**: Draft / Planning  
**Applicable to**: Salt masterless workstation configuration (CachyOS/Arch)  
**Current version**: Salt 3007.13  
**Target version**: Salt 3008+ LTS (when available)

## Executive Summary

This guide describes a safe, isolated approach to upgrading Salt from 3007.13 to 3008+ using git worktrees. The methodology ensures:

- **Zero interference** with the production configuration during testing
- **Complete isolation** of upgrade changes in a separate worktree
- **Incremental validation** of all state files, macros, and data
- **Controlled integration** after successful testing
- **Easy rollback** by simply removing the worktree

## Why Git Worktrees?

### Advantages Over Traditional Branch Workflow

| Aspect | Traditional Branch | Git Worktree |
|--------|-------------------|--------------|
| **Isolation** | Same directory, risk of accidental commits | Separate directory, complete isolation |
| **Parallel work** | Must stash/commit before switching | Can work in both simultaneously |
| **Testing safety** | Risk of breaking working config | Production config remains untouched |
| **Cleanup** | Need to reset/clean working directory | Simply delete worktree directory |
| **Existing practice** | Standard git workflow | Already used in this project (`.worktrees/`) |

### Project Context

This project already uses git worktrees for parallel development (see `.worktrees/` directory). Extending this pattern for major upgrades provides consistency and reduces cognitive overhead.

## Prerequisites

### System Requirements
- Git 2.5+ (worktree support)
- Python 3.12+ (Salt 3008 compatibility)
- Existing Salt 3007.13 installation
- Sufficient disk space for duplicate repository

### Repository State
- Clean working directory in main worktree
- All changes committed or stashed
- No unmerged branches

### Knowledge Requirements
- Basic git worktree commands
- Salt state structure and testing tools
- Project's `just` command workflow

## Upgrade Process Overview

```text
graph TD
    A[Start: Clean main worktree] --> B[Create upgrade worktree]
    B --> C[Research Salt 3008 changes]
    C --> D[Update requirements.txt]
    D --> E[Test rendering just validate]
    E --> F[Test macros & data]
    F --> G[Adapt scripts]
    G --> H[Integration testing]
    H --> I{All tests pass?}
    I -->|Yes| J[Merge to main]
    I -->|No| K[Fix in worktree]
    K --> E
    J --> L[Cleanup worktree]
    L --> M[Documentation update]
```

## Phase 1: Worktree Setup (1 day)

### 1.1 Create Upgrade Worktree

```bash
# From the main repository directory
cd /home/neg/src/cfg

# Create new worktree with dedicated branch
git worktree add .worktrees/salt-3008-upgrade -b upgrade/salt-3008

# Verify creation
git worktree list
```

Expected output:
```
/home/neg/src/cfg                                145bad2 [main]
/home/neg/src/cfg/.worktrees/salt-3008-upgrade   145bad2 [upgrade/salt-3008]
```

### 1.2 Initialize Worktree Environment

```bash
# Switch to worktree
cd .worktrees/salt-3008-upgrade

# Set up virtual environment (if not inheriting from main)
python -m venv .venv
source .venv/bin/activate

# Install current dependencies (baseline)
pip install -r requirements.txt

# Verify tools work
just --version
pytest --version
```

### 1.3 Baseline Validation

```bash
# Ensure current state renders correctly (3007.13)
just validate

# Run quick smoke test
just test system_description

# Record baseline performance
just test system_description 2>&1 | tail -5 > /tmp/baseline-perf.txt
```

## Phase 2: Compatibility Research (2-3 days)

### 2.1 Salt 3008 Change Analysis

**Critical investigation areas:**

1. **Module stability** - Check if core modules remain in Salt core:
   - `file.managed`, `cmd.run`, `service.running`
   - `pkg.installed`, `mount.mounted`, `sysctl.present`
   - `kmod.present`, `timezone.system`

2. **Jinja2/YAML changes** - Breaking changes in templating:
   - Filter function availability
   - YAML loading behavior
   - Context variable access

3. **Performance changes** - New defaults affecting execution:
   - Parallel execution behavior
   - Cache invalidation rules
   - State compilation overhead

### 2.2 Data Sources

- Official Salt 3008 release notes (when available)
- Salt Project blog and announcements
- GitHub issues with `3008` label
- `docs/salt-best-practices.md` watch signals

### 2.3 Risk Assessment Matrix

| Component | Risk Level | Impact | Mitigation Strategy |
|-----------|------------|--------|---------------------|
| Jinja macros | Medium | High | `just validate` all states before execution |
| YAML data files | Low | Medium | Syntax validation with `yamllint` |
| Salt modules | High | Critical | Test each module type in isolation |
| Script compatibility | Medium | High | Update `salt_compat.py` as needed |
| Performance regressions | Medium | Medium | Baseline vs. target comparison |

## Phase 3: Dependency Update (1 day)

### 3.1 Update Requirements

```bash
# In worktree directory
cd .worktrees/salt-3008-upgrade

# Edit requirements.txt
sed -i 's/salt==3007.13/salt>=3008,<3009/' requirements.txt

# Check salt-lint compatibility
# May need to update or temporarily disable
```

### 3.2 Install New Dependencies

```bash
# Clean install in worktree
deactivate
rm -rf .venv
python -m venv .venv
source .venv/bin/activate

pip install -r requirements.txt

# Verify installation
python -c "import salt; print(f'Salt version: {salt.__version__}')"
```

### 3.3 Verify Core Dependencies

```bash
# Critical dependency checks
python -c "import jinja2; print(f'Jinja2: {jinja2.__version__}')"
python -c "import yaml; print(f'PyYAML available')"
python -c "import tornado; print(f'Tornado: {tornado.version}')"

# Test basic Salt functionality
python -c "
import salt.config
import salt.loader
opts = salt.config.minion_config(None)
grains = salt.loader.grains(opts)
print(f'Grains loaded: {bool(grains)}')
"
```

## Phase 4: Rendering Validation (2 days)

### 4.1 Comprehensive State Validation

```bash
# Test all state files render without errors
just validate

# If validation fails, diagnose specific files
just validate-one system_description
just validate-some desktop hyprland

# Check feature matrix scenarios
just render-matrix
```

### 4.2 Macro-Specific Testing

```bash
# Create test rendering for complex macros
cat > /tmp/test_macro.j2 << 'EOF'
{% from '_macros_service.jinja' import ensure_dir, user_service_file %}
Test: {{ ensure_dir('test', '/tmp/test', mode='0755') }}
{% set service = {'name': 'test', 'exec': '/bin/true', 'user': 'neg'} %}
{{ user_service_file(service) }}
EOF

# Render with Salt's jinja
python -c "
import jinja2
env = jinja2.Environment(
    loader=jinja2.FileSystemLoader(['states/']),
    extensions=['jinja2.ext.do']
)
template = env.from_string(open('/tmp/test_macro.j2').read())
print(template.render())
"
```

### 4.3 Data File Validation

```bash
# Validate all YAML data files
find states/data -name "*.yaml" -exec yamllint {} \;

# Test YAML loading with Salt's parser
python -c "
import yaml
import salt.utils.yaml
with open('states/data/packages.yaml') as f:
    data = salt.utils.yaml.safe_load(f)
print(f'Packages categories: {len(data)}')
"
```

## Phase 5: Script Adaptation (2 days)

### 5.1 Salt Daemon Compatibility

Check `scripts/salt-daemon.py` for:
- Module import paths (may change in 3008)
- State execution API changes
- Log format compatibility
- Socket communication stability

```bash
# Test daemon startup (dry-run)
python scripts/salt-daemon.py --config-dir .salt_runtime --dry-run

# Check module loading
python -c "
import salt.loader
import salt.config
opts = salt.config.minion_config(None)
modules = salt.loader.minion_mods(opts)
print(f'Modules loaded: {len(modules)}')
"
```

### 5.2 Runner Script Updates

Update `scripts/salt_runner.py`:
- CLI argument parsing changes
- Output format compatibility
- Error handling improvements

### 5.3 Compatibility Layer Review

Review `scripts/salt_compat.py`:
- Remove Python 3.13+ patches if fixed in Salt 3008
- Update URL handling if `salt://` changes
- Check multiprocessing compatibility

```bash
# Test compatibility patches
python -c "
import sys
sys.path.insert(0, 'scripts')
import salt_compat
salt_compat.patch()
print('Compatibility patches applied')
"
```

## Phase 6: Integration Testing (3-4 days)

### 6.1 Dry-Run Testing Strategy

```bash
# Test core functionality first
just test system_description

# Test state groups incrementally
just test group core
just test group desktop
just test group packages
just test group services
just test group ai

# Check idempotency
just idempotency system_description
```

### 6.2 Performance Benchmarking

```bash
# Capture performance baseline
just test system_description 2>&1 | tee /tmp/salt-3008-perf.log

# Analyze with profiler
just profile /tmp/salt-3008-perf.log

# Compare with baseline
just profile-compare /tmp/baseline-perf.txt /tmp/salt-3008-perf.log
```

### 6.3 Edge Case Testing

```bash
# Test complex states with dependencies
just test video_ai
just test ollama
just test nanoclaw

# Test service management
just test user_services
just test systemd_resources

# Test package installation flows
just test installers
just test custom_pkgs
```

## Phase 7: Virtual Environment Testing (1-2 days)

### 7.1 CachyOS VM Smoke Test

```bash
# Prepare test environment
just vm-smoke /mnt/one/cachyos-root

# Monitor for regressions
tail -f logs/vm-smoke-*.log
```

### 7.2 Full Apply Test

```bash
# WARNING: Only in isolated VM environment
just apply system_description --test-run

# Verify no destructive changes
grep -i "failed\|error" logs/system_description-*.log
```

## Phase 8: Integration to Main (1 day)

### 8.1 Final Validation Checklist

- [ ] All states render without errors (`just validate`)
- [ ] Dry-run passes without changes (`just test system_description`)
- [ ] All tests pass (`pytest tests/`)
- [ ] Idempotency verified (`just idempotency`)
- [ ] Performance acceptable (`just profile-compare`)
- [ ] Documentation updated
- [ ] Rollback plan documented

### 8.2 Merge Process

```bash
# From main worktree directory
cd /home/neg/src/cfg

# Ensure main branch is clean
git status

# Merge upgrade branch
git checkout main
git merge upgrade/salt-3008 --no-ff -m "[feat] upgrade to Salt 3008"

# Run final validation
just validate
just test system_description
pytest tests/ -v
```

### 8.3 Post-Merge Verification

```bash
# Update virtual environment in main directory
deactivate
cd /home/neg/src/cfg
rm -rf .venv
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# Final smoke test
just test group core
just test group desktop
```

## Phase 9: Cleanup and Documentation (1 day)

### 9.1 Worktree Cleanup

```bash
# Remove worktree
git worktree remove .worktrees/salt-3008-upgrade

# Delete branch (optional)
git branch -d upgrade/salt-3008

# Verify cleanup
git worktree list
```

### 9.2 Documentation Updates

Update the following files:
1. `AGENTS.md` - Update Salt version and compatibility notes
2. `docs/salt-best-practices.md` - Add 3008-specific guidance
3. `README.md` - Update version references if needed
4. This guide - Convert from draft to reference

### 9.3 Knowledge Transfer

Create summary document:
- Breaking changes encountered
- Workarounds implemented
- Performance characteristics
- Recommendations for future upgrades

## Risk Management Strategy

### Critical Risks and Mitigations

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| **Salt module deprecation** | Medium | Critical | Test each module type; have fallback ready |
| **Jinja rendering breakage** | Low | High | `just validate` before any execution |
| **Performance regression** | Medium | Medium | Baseline comparison; profile early |
| **Script incompatibility** | High | High | Update scripts in worktree first |
| **Data format changes** | Low | Medium | YAML validation; gradual migration |

### Rollback Procedures

**Scenario 1: Worktree testing fails**
```bash
# Simply delete worktree
git worktree remove .worktrees/salt-3008-upgrade
git branch -d upgrade/salt-3008
```

**Scenario 2: Merge causes issues**
```bash
# Revert merge
git revert -m 1 <merge-commit>

# Or reset if no other changes
git reset --hard HEAD~1
```

**Scenario 3: Production system affected**
```bash
# Revert to previous Salt version in requirements.txt
sed -i 's/salt>=3008,<3009/salt==3007.13/' requirements.txt

# Reinstall dependencies
pip install -r requirements.txt --force-reinstall

# Apply known-good configuration
just apply system_description
```

## Success Criteria

### Must-Have (Blocking)
- [ ] All 200+ state files render without errors
- [ ] Dry-run of `system_description` makes zero changes
- [ ] All existing tests pass (`pytest tests/`)
- [ ] Idempotency verified for core states
- [ ] No regressions in critical functionality

### Should-Have (Important)
- [ ] Performance within 10% of baseline
- [ ] All macros function correctly
- [ ] Data files load without warnings
- [ ] Scripts updated and tested
- [ ] Documentation complete

### Nice-to-Have (Optional)
- [ ] Performance improvements from 3008 features
- [ ] New Salt 3008 features utilized
- [ ] Code quality improvements
- [ ] Additional test coverage

## Appendices

### Appendix A: Git Worktree Commands Cheat Sheet

```bash
# List worktrees
git worktree list

# Add new worktree
git worktree add <path> [-b <branch>]

# Move between worktrees
cd <worktree-path>

# Remove worktree
git worktree remove <path>

# Prune stale worktrees
git worktree prune
```

### Appendix B: Salt Testing Commands

```bash
# Core validation
just validate                    # Render all states
just render-matrix              # Test feature matrix
just test <state>              # Dry-run specific state
just test group <group>        # Dry-run state group

# Advanced testing
just idempotency <state>       # Verify idempotency
just profile <log>             # Profile performance
just profile-trend             # Analyze trends
just profile-compare <a> <b>   # Compare two runs

# Quality checks
just lint                      # Run all linters
pytest tests/ -v              # Run test suite
```

### Appendix C: Useful Salt 3008 Resources

1. **Official Documentation**
   - [Salt 3008 Release Notes](https://docs.saltproject.io/en/latest/topics/releases/3008.0.html)
   - [Migration Guide](https://docs.saltproject.io/en/latest/topics/releases/migration.html)

2. **Community Resources**
   - Salt Project Blog
   - GitHub Discussions
   - #salt IRC channel

3. **Project References**
   - `docs/salt-best-practices.md`
   - `docs/pyinfra-migration-research.md`
   - `AGENTS.md`

### Appendix D: Change Log Template

```markdown
## Salt 3008 Upgrade - Change Log

### Breaking Changes Encountered
1. **Module changes**: [Description]
2. **API changes**: [Description]
3. **Behavior changes**: [Description]

### Workarounds Implemented
1. [Issue]: [Solution]
2. [Issue]: [Solution]

### Performance Impact
- State compilation: ±X%
- Execution time: ±Y%
- Memory usage: ±Z%

### Recommendations
1. For future upgrades: [Advice]
2. Configuration changes: [Suggestions]
3. Testing strategy: [Improvements]
```

## Conclusion

This git worktree-based upgrade approach provides maximum safety and isolation for migrating to Salt 3008+. By testing in a completely separate environment, you can:

1. **Avoid disrupting** your production configuration
2. **Test thoroughly** without risk
3. **Iterate quickly** on fixes
4. **Integrate cleanly** when ready
5. **Rollback instantly** if needed

The methodology aligns with existing project practices and provides a template for future major upgrades of Salt or other critical infrastructure components.

**Next Steps**: Begin Phase 1 when Salt 3008 LTS is released and initial compatibility research is complete.
```

---

*Document version: 1.0*  
*Last updated: 2026-04-18*  
*Maintainer: Infrastructure Team*  
*Based on: Project's existing Salt 3007.13 configuration and git worktree practices*