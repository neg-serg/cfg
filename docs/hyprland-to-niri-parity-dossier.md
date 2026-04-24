# Hyprland -> Niri Feature-Parity Dossier

## Executive Summary

- Strongest parity wins: core directional focus and PiP floating are already represented natively in `dotfiles/dot_config/niri/config.kdl`; search-first launching, focus-history switching, screenshots, and retained Hyprland fallback all have credible helper-backed parity paths.
- Highest-risk gaps: `allow_tearing` remains a hard blocker with no reconstruction path; `direct_scanout`, scrolling-layout refinements, hierarchical key hints, and repo-managed night-light or ICC workflows still have explicit no-parity or high-risk gaps.
- Current honest strategy: Hybrid-first or Do not cut over yet
- Upgrade conditions: helper-backed hotkey discoverability must be proven from the existing shortcut catalog, color-comfort workflows need a repo-managed path, and live verification must close the unresolved display items before the recommendation can improve.

## Scope and Baseline

The baseline is not just the Hyprland compositor config. It is the combined workstation UX encoded across several repository artifacts:

- `dotfiles/dot_config/hypr/shortcuts.yaml` for the semantic action catalog, grouped shortcuts, and launcher taxonomy.
- `dotfiles/dot_config/wlr-which-key/config.yaml` for hierarchical key discovery.
- `dotfiles/dot_config/hypr/bindings/media.conf` for XF86 volume, mute, brightness, and transport keys wired through `swayosd-client` and `playerctl`.
- `docs/hyprland-to-niri-migration-notes.md` for the current migration state, translated bind examples, and explicit missing-feature notes.
- `dotfiles/dot_config/niri/config.kdl` for the current Niri-side reality: outputs, layout, binds, window rules, and animations.
- `states/desktop/niri.sls` for the package and portal stack that currently backs the Niri setup.
- `dotfiles/dot_local/bin/executable_niri-focus-hist` and `tests/test_niri_focus_hist.py` for an existing helper-based parity example already adapted to Niri IPC.
- `TODO.md` for the still-open hierarchical key-hint goal that goes beyond a search-only launcher.

This dossier therefore evaluates workstation parity across hotkeys, discoverability, launchers, layout, display behavior, helper tooling, and rollback safety rather than compositor syntax alone.

## Evidence Model

This dossier uses four evidence types:

1. Repo evidence: current configs, scripts, tests, and operator notes already tracked in this repository.
2. Platform capability evidence: capability claims already captured in migration notes or otherwise supportable without guesswork.
3. Helper-stack evidence: existing or candidate tools such as `xwayland-satellite`, `vicinae`, `wlr-which-key`, `swayosd`, and compositor-adjacent scripts.
4. Operator-experience evidence: places where a workflow may still feel different even if a raw feature exists.

Any display-, latency-, or color-sensitive item that cannot be proven from repository evidence alone must be marked `Unknown; needs live verification` rather than upgraded optimistically.

## Strict Parity Matrix
| Feature | Current source in repo | User-visible expectation | Native Niri status | External reconstruction path | Parity status | Residual mismatch | Operator cost | Blocker severity |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Core directional focus and move binds | `docs/hyprland-to-niri-migration-notes.md`, `dotfiles/dot_config/niri/config.kdl` | `Mod+H/J/K/L` focuses predictably and `Mod+Ctrl+H/J/K/L` reorders windows without relearning | Present in `config.kdl` | None | Native parity | Feel still needs runtime validation | Low | None |
| Search-first launcher | `dotfiles/dot_config/hypr/shortcuts.yaml`, `dotfiles/dot_config/niri/config.kdl` | `Mod+D` opens the same search-oriented launcher surface quickly | Present as `spawn "vicinae" "toggle"` | Existing `vicinae` service | Parity via helper stack | Depends on an external launcher service rather than a compositor-native surface | Low | None |
| Hierarchical key hints | `dotfiles/dot_config/wlr-which-key/config.yaml`, `TODO.md` | Prefix-based key discovery stays available without diverging from the main shortcut catalog | No direct Niri equivalent is configured today | Reuse `wlr-which-key` or generate a Niri-aligned helper surface from `shortcuts.yaml` | Unknown; needs live verification | Wiring and parity with the current tree are not yet proven under Niri | Medium | High |
| Catalog-driven shortcut taxonomy | `dotfiles/dot_config/hypr/shortcuts.yaml`, `scripts/generate_hypr_shortcuts.py` | Search, documentation, and grouped hints all derive from one source of truth | Not implemented on the Niri side today | Generate Niri-facing docs and helper inputs from `shortcuts.yaml` | Partial parity | The catalog exists, but Niri is not yet consuming it as a first-class source | Medium | High |
| Scratchpad action menu | `dotfiles/dot_config/hypr/shortcuts.yaml`, `dotfiles/dot_config/wlr-which-key/config.yaml` | Named scratchpads remain quickly reachable and discoverable | No direct Niri mapping is documented today | Keep existing scripts and rebind through Niri plus helper menus | Unknown; needs live verification | Script behavior may survive, but menu- and bind-level continuity is not yet proven | Medium | Medium |
| Focus-history switching | `dotfiles/dot_local/bin/executable_niri-focus-hist`, `tests/test_niri_focus_hist.py` | The last-focused window can be revisited under Niri without manual reimplementation | Helper already exists | Existing Niri IPC helper script | Parity via helper stack | Needs a live session validation, but the helper and contract tests exist | Low | Low |
| Lock flow with keyboard-layout reset | `dotfiles/dot_config/hypr/shortcuts.yaml`, `dotfiles/dot_config/wlr-which-key/config.yaml` | Locking also resets the layout to a known state before `hyprlock` | The current implementation is Hyprland-specific | Rewrite the pre-lock command for Niri or split layout reset from the lock action | Unknown; needs live verification | The current command still shells out to `hyprctl` | Medium | Medium |
| Browser and utility app matching | `docs/hyprland-to-niri-migration-notes.md`, `dotfiles/dot_config/niri/config.kdl` | Browsers tile consistently and utility windows float when expected | Partially present via `app-id` and title rules | Extend the rule set and verify against live app IDs | Partial parity | Rule translation exists, but full behavioral coverage is not yet demonstrated | Medium | Medium |
| Picture-in-Picture floating | `docs/hyprland-to-niri-migration-notes.md`, `dotfiles/dot_config/niri/config.kdl` | PiP windows float immediately instead of disrupting the tiling flow | Present via title match | None | Native parity | Needs only a live sanity check | Low | None |
| Core scrolling layout | `docs/hyprland-to-niri-migration-notes.md`, `dotfiles/dot_config/niri/config.kdl` | Column-based tiling and width presets remain available | Present | None | Native parity | Missing refinements are tracked separately | Low | None |
| Scroll-follow refinements | `docs/hyprland-to-niri-migration-notes.md` | Focus-following, one-column fullscreen, visibility heuristics, and direction tuning behave the same as Hyprland scrolling | No equivalents recorded in current notes | None proven | No parity | The simpler Niri model changes how large workspaces feel and scroll | Low | High |
| XWayland application support | `docs/hyprland-to-niri-migration-notes.md`, `states/desktop/niri.sls` | X11-only apps still launch and render predictably | Present through the `xwayland-satellite` package path | Existing helper package | Parity via helper stack | Needs live validation for specific apps, not just package presence | Low | Medium |
| Portal integration | `docs/hyprland-to-niri-migration-notes.md`, `states/desktop/niri.sls` | File pickers and screenshot portals keep working in daily apps | Package support is present | Existing portal packages | Unknown; needs live verification | Package installation does not prove dialog behavior | Low | Medium |
| Full-screen and area screenshots | `dotfiles/dot_config/hypr/shortcuts.yaml`, `dotfiles/dot_config/wlr-which-key/config.yaml` | Full and region screenshot flows keep their current commands and file output behavior | No direct Niri bind wiring is documented today | Rebind existing `grim` and `slurp` flows under Niri | Parity via helper stack | Helper commands already exist, but Niri-side bind parity is not yet documented | Low | Low |
| Screen and area recording | `dotfiles/dot_config/hypr/shortcuts.yaml`, `dotfiles/dot_config/wlr-which-key/config.yaml` | Screen recording and area recording remain available from the same launcher taxonomy | No direct Niri bind wiring is documented today | Rebind existing `~/.local/bin/screenrec` flows under Niri | Unknown; needs live verification | Script continuity is likely, but runtime behavior and ergonomics under Niri are not yet proven | Low | Medium |
| Variable refresh rate | `docs/hyprland-to-niri-migration-notes.md`, `dotfiles/dot_config/niri/config.kdl` | The main display keeps VRR behavior under Niri | Configured, but not yet confirmed on the real host | Live validation with `niri msg outputs` | Unknown; needs live verification | Config presence alone does not prove real VRR behavior | Low | Medium |
| 10-bit output path | `docs/hyprland-to-niri-migration-notes.md` | 10-bit output remains available on the target monitor | No explicit force option in Niri | None beyond DRM/KMS auto-detection and visual testing | Unknown; needs live verification | Niri cannot force the setting the way Hyprland did | None | High |
| Allow tearing | `docs/hyprland-to-niri-migration-notes.md` | Fast fullscreen workloads can trade visual integrity for lower latency | No equivalent recorded | None | No parity | Latency-sensitive scenarios may feel worse even if general desktop usage is fine | None | Hard blocker |
| Direct scanout | `docs/hyprland-to-niri-migration-notes.md` | Fullscreen apps can bypass more compositor overhead when possible | No equivalent recorded | None | No parity | Potential fullscreen performance delta remains unresolved | None | High |
| XF86 volume, mute, and transport keys | `dotfiles/dot_config/hypr/bindings/media.conf` | Hardware media keys keep working and still surface OSD feedback | Not configured in `dotfiles/dot_config/niri/config.kdl` today | Rebind the same `swayosd-client` and `playerctl` commands under Niri | Parity via helper stack | Requires explicit Niri-side rebinding, but the command layer already exists | Low | Low |
| XF86 brightness keys with OSD | `dotfiles/dot_config/hypr/bindings/media.conf` | Brightness keys change backlight and display feedback immediately | Not configured in the current Niri config | Rebind existing `swayosd-client --brightness` actions under Niri | Unknown; needs live verification | The repo shows the command path, but not a proven Niri-side deployment | Low | Medium |
| Night light and color temperature shift | `docs/hyprland-to-niri-migration-notes.md`, repo-wide search for `gammastep|wlsunset|colord|icc` | Evening color temperature can be shifted predictably without manual one-off shell work | No managed path is documented today | Candidate helper path only; no repo-managed solution yet | Unknown; needs live verification | The repo does not currently prove a maintained Niri-compatible workflow | Medium | High |
| ICC or per-output color profile workflow | `docs/hyprland-to-niri-migration-notes.md`, repo-wide search for `icc|colord` | The workstation can preserve calibrated output behavior, not just raw 10-bit transport | No managed path is documented today | Candidate external tooling only | Unknown; needs live verification | Repo evidence for a calibration workflow is absent today | High | High |
| Visual comfort beyond raw output capability | `docs/hyprland-to-niri-migration-notes.md` | Evening work remains comfortable, predictable, and easy to toggle | Not proven | Would require explicit helper selection plus operator documentation | Partial parity | Raw display support and user comfort are not the same thing | Medium | High |
| Hyprland remains installed as fallback | `docs/hyprland-to-niri-migration-notes.md` | A failed Niri cutover does not strand the workstation without a known-good compositor path | Present in the current migration design | Existing retained Hyprland setup | Parity via helper stack | Safety depends on continuing to keep the Hyprland path healthy | Low | Low |
| Rollback drill confidence | `docs/hyprland-to-niri-migration-notes.md` | The operator can revert quickly and confidently rather than only in theory | Procedure is documented, but not proven in the dossier | Practice the rollback and record evidence | Unknown; needs live verification | A written rollback plan is weaker than a rehearsed rollback | Low | Medium |
| Long-lived hybrid operation | `docs/hyprland-to-niri-migration-notes.md`, `states/desktop/niri.sls` | Niri can be used daily while Hyprland remains a maintained fallback instead of a stale emergency path | Plausible from current state layout | Keep both stacks managed and documented | Partial parity | Operational drift can accumulate if one compositor path stops receiving attention | Medium | Medium |

## Domain Analysis
### Hotkeys and Muscle Memory

The current keyboard UX is catalog-driven, not compositor-local. The semantic action inventory lives in `dotfiles/dot_config/hypr/shortcuts.yaml`, while `wlr-which-key` and `vicinae` expose two different discovery surfaces over the same command taxonomy. That means parity is not achieved merely by porting a handful of direct binds into `dotfiles/dot_config/niri/config.kdl`.

`dotfiles/dot_config/niri/config.kdl` already preserves a small core of direct navigation and launch binds such as `Mod+H/J/K/L`, workspace cycling, `Mod+Return`, `Mod+D`, and `Mod+Shift+D`. The parity gap sits higher in the stack: grouped actions, discoverable menus, scratchpad access, and lock or power flows that currently rely on Hyprland-flavored commands or generated helper data.

### Discoverability and Key Hints

The current system supports both search-first discovery and hierarchical discovery. The future cutover should treat this dual model as intentional rather than optional polish: search covers recall failure, while grouped hints cover exploration and muscle-memory rehearsal.

Any Niri-era setup that keeps `vicinae` but loses the current `wlr-which-key` style tree should be scored as reduced parity unless that loss is explicitly accepted.

### Launchers and Command Catalog

The command catalog already has structure: apps, scratchpads, power, screenshots, selectors, media, and special tools are grouped semantically in `dotfiles/dot_config/hypr/shortcuts.yaml`. If Niri ends up with a second, compositor-specific bind inventory, parity may look high superficially while the real operator model becomes harder to learn, debug, and maintain.

For parity-first evaluation, the single-source-of-truth question is part of the feature set, not an implementation detail.

### Window Rules, Floating, and Transient Behavior

The current migration notes already translate several Hyprland rule families into Niri `app-id` and `title` rules, but rule parity is only native for the subset already carried into `dotfiles/dot_config/niri/config.kdl`. Any behavior that depends on broader Hyprland rule ecosystems, workspace-side conventions, or unverified app identifiers still requires explicit checking.

### Scrollable-Layout Behavior

Niri preserves the core scrolling-column concept and the current column width presets, but the existing notes already record missing refinements such as `fullscreen_on_one_column`, `follow_focus`, `follow_min_visible`, and explicit direction control. These should be treated as named parity losses until proven otherwise.

### Brightness, Media, and OSD

The current media and brightness surface is only partly about key bindings. `dotfiles/dot_config/hypr/bindings/media.conf` couples XF86 keys to `swayosd-client`, so parity depends on preserving both the action and the operator feedback layer. A cutover that keeps the keys but loses reliable OSD or brightness control should be scored as degraded parity, not silent success.

### Color Correction, Gamma, ICC, and Night Workflows

The current repository has explicit attention to VRR and 10-bit output, but it does not yet contain a repo-managed `gammastep`, `wlsunset`, `colord`, or ICC pipeline for Niri. That absence must be written down directly: color-comfort parity is currently an unresolved area, not a solved one.

Raw output capability and lived visual comfort are not identical. A parity-first recommendation therefore has to ask whether late-night work, brightness changes, color-temperature shifts, and calibration-sensitive behavior remain easy enough to trust every day.

### Portals, Screenshots, Recording, and XWayland

This domain mixes three different kinds of parity. XWayland is mostly a package-and-runtime question, portals are a desktop-integration question, and screenshots or recording are workflow questions built on launcher entries and helper scripts such as `grim`, `slurp`, and `screenrec`. The dossier should keep those together only if it still names each subtype separately.

Package presence for `xwayland-satellite` and portal providers is encouraging, but it does not prove that daily file-pickers, screenshot portals, manual screenshot commands, and area recording flows all behave the same way under Niri.

### 10-bit, VRR, and Latency-Sensitive Behavior

The current notes already warn that `allow_tearing` and `direct_scanout` have no direct Niri equivalents. A parity-first dossier must treat those as real behavioral gaps for latency-sensitive work rather than burying them inside a generic performance caveat.

VRR and 10-bit support belong in the same section for a different reason: the repository has intent and config for both, but neither is proven solely by config presence. The dossier should therefore distinguish between configured intent and validated behavior.

### Rollback and Dual-Compositor Safety

The existing migration notes describe the cutover as non-destructive because Hyprland remains installed and configured. That is a real parity advantage in itself: the system can support an honest hybrid period instead of forcing an all-or-nothing switch.

At the same time, rollback safety should not be treated as merely theoretical. The dossier should distinguish between "Hyprland is still present on disk" and "the operator can revert quickly, predictably, and without rediscovering missing config or package prerequisites".

## No-Parity Register

| Gap | Why it is missing | Candidate helper | Residual mismatch | Full-cutover impact |
| --- | --- | --- | --- | --- |
| Scrolling-layout refinements (`fullscreen_on_one_column`, `follow_focus`, `follow_min_visible`, `direction`) | Existing migration notes record no Niri equivalent | None proven | Workspace navigation will feel simpler and less steerable than Hyprland scrolling | High risk for parity-first cutover |
| `allow_tearing` | Existing migration notes record no Niri equivalent | None | Latency-sensitive fullscreen scenarios lose a known tuning knob | Hard blocker for gaming-first parity |
| `direct_scanout` | Existing migration notes record no Niri equivalent | None | Fullscreen rendering path may carry extra compositor overhead | High risk for performance-sensitive use |
| Hierarchical hints generated from the semantic shortcut catalog | The repo has `wlr-which-key` data, but Niri-side wiring and generation are not yet proven | Reuse `wlr-which-key` or generate a new helper surface | Discoverability can drift away from the main catalog if helper wiring is ad hoc | High risk for hotkey-parity claims |
| Repo-managed night light and ICC workflow | The repo currently lacks a managed Niri-era gamma or ICC path | Candidate helper tools only | Visual comfort parity cannot be claimed yet | High risk for color-sensitive and late-night use |

## Strategy Comparison

### Full cutover to Niri
This is only honest if the open hotkey-discoverability gaps, color-workflow gaps, and latency-sensitive no-parity items are either closed or explicitly accepted as non-blocking. Current repository evidence does not yet support that conclusion.

### Cutover to Niri with helper stack
This path is plausible for launcher, media, OSD, XWayland, portals, and focus-history behavior, but it still needs disciplined helper selection so parity claims remain reproducible rather than improvised.

### Hybrid: Niri plus retained Hyprland path
This is the most honest near-term strategy if the daily desktop benefits of Niri are attractive but gaming, advanced scrolling behavior, or color-comfort flows still require Hyprland.

### Stay on Hyprland for now
This remains the safest parity-first recommendation until the no-parity register shrinks and the unknown display and color items are resolved.

## Grand Quiz
### Answer Scale
Use this scale for every question:
- Need native-equivalent behavior
- Helper-based parity is acceptable
- Partial parity is acceptable
- Different workflow is acceptable
- Not important for my cutover decision

### Keyboard Parity

Q1. If direct window navigation survives but grouped launcher chords move, is that still acceptable?
Q2. Do named scratchpads need to keep their current access patterns rather than only their underlying commands?
Q3. Does the lock flow need to normalize keyboard layout before `hyprlock` or its equivalent?
Q4. Would helper-generated Niri binds still count as success if the end-user chords stay stable?

### Discoverability Parity

Q5. Do you need a prefix-hint tree in addition to search, not just one of the two?
Q6. Is it acceptable if the hint surface lives outside the compositor as long as the taxonomy stays unified?
Q7. Is drift between the search catalog and the hint tree acceptable for rarely used actions?
Q8. Do you need future-you to recover obscure actions without remembering exact chords first?

### Launcher Parity

Q9. Must `Mod+D` keep its current search-first launcher semantics?
Q10. Must launcher entries still support raise-or-launch behavior instead of simple spawning?
Q11. Is preserving grouped submenus as important as preserving individual commands?
Q12. Can launcher behavior depend on a long-running helper such as `vicinae` without counting as degraded parity?

### Visual Comfort Parity

Q13. Do brightness keys need both the action and the OSD feedback layer to count as preserved?
Q14. Is smooth visual feedback more important than minimizing the number of helper processes?
Q15. Would helper-based brightness handling be acceptable if it still feels instant and trustworthy?
Q16. If evening comfort becomes slightly worse while daytime clarity stays fine, is cutover still viable?

### Color and Night-Work Parity

Q17. Do you need a one-step night-light toggle that is reliable enough for daily use?
Q18. Do you need per-output calibration behavior rather than only global gamma shifting?
Q19. Is `10-bit probably works` acceptable, or do you need explicit control and verification?
Q20. If ICC and gamma tooling lives completely outside the compositor, does that still count as honest parity for you?

### Window-Management Parity

Q21. Must floating utility windows behave identically without retraining?
Q22. Do PiP, browser, and utility matches need deterministic routing from day one?
Q23. Are simpler scrolling semantics acceptable if core column navigation survives?
Q24. Would you trade some layout refinement for a cleaner and smaller ruleset?

### Gaming and Latency Parity

Q25. Is missing `allow_tearing` a cutover blocker for your real workload?
Q26. Is missing `direct_scanout` a blocker even if general desktop UX improves?
Q27. Do you need one compositor for both desktop and latency-sensitive fullscreen use?
Q28. Would a hybrid model be acceptable if Niri wins for daily work but not for games?

### Operational Complexity Tolerance

Q29. Are you willing to run extra user services if they preserve launcher, OSD, or hint behavior?
Q30. Is a generated shortcut pipeline acceptable if it keeps the command catalog single-sourced?
Q31. Do helper-managed workflows count as success only if they are Salt-managed and reviewable?
Q32. Would you rather keep Hyprland than depend on a fragile glue layer that only looks equivalent on paper?

### Rollback Confidence

Q33. Do you need Hyprland to remain one switch away until all high-risk gaps are closed?
Q34. Is it acceptable to run Niri daily while Hyprland remains a standing fallback?
Q35. Would you refuse a cutover while any display or color item remains `Unknown; needs live verification`?
Q36. Do you require a documented rollback drill before declaring parity success?

## Outcome Rubric

- `Niri-ready`: no `Hard blocker` rows remain, no domain marked `No parity` is tied to a `Need native-equivalent behavior` answer, and unknown display or color items have been resolved.
- `Niri-ready with glue`: unresolved native gaps all have helper paths, and every helper-dependent domain is answered with `Helper-based parity is acceptable`.
- `Hybrid-first`: Niri is acceptable for daily desktop work, but one or more of gaming and latency, color comfort, or discovery-heavy hotkey workflows still conflict with must-have answers.
- `Do not cut over yet`: any hard blocker remains active, or any `Need native-equivalent behavior` answer maps to a row still marked `No parity`, `Partial parity`, or `Unknown; needs live verification`.

When the rubric and the matrix disagree, the matrix wins. The dossier must not use a permissive quiz result to paper over an explicit blocker.

## Recommendation

Based on current repository evidence alone, the honest provisional recommendation is `Hybrid-first` or `Do not cut over yet`, not `Full cutover`. The dossier can only be upgraded after helper-backed hotkey parity, color-comfort tooling, and live display verification are documented.
