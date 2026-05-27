{# Desktop environment: top-level include for compositor, packages, portal, and user session #}
{#- @state
   id: desktop
   purpose: "Desktop environment: top-level include for compositor, packages, portal, and user session."
   includes: [desktop.hyprland, desktop.packages, desktop.portal, desktop.system, desktop.user, desktop.nothing_kde_widgets, desktop.vm_win11, desktop.themes]
#}
# =============================================================================
# Desktop environment — top-level include for system, packages, portal, hyprland, user
# =============================================================================
# desktop.niri is an alternative scrolling-tiling compositor — not wired in yet
# (see docs/hyprland-to-niri-migration-notes.md). Include it here with a feature
# gate when the migration is ready.
include:
  - desktop.system
  - desktop.packages
  - desktop.portal
  - desktop.hyprland
  - desktop.user
  - desktop.nothing_kde_widgets
  - desktop.vm_win11
  - desktop.themes
