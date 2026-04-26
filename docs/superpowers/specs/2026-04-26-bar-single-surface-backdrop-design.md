# Bar Single-Surface Backdrop Design

## Summary

The Quickshell bar currently renders its visual background through multiple adjacent layer surfaces.
Even after disabling explicit seam shaders and diagonal backdrop masks, a visible seam remains at the center of the screen.
Pixel inspection of `satty-20260426-06.19.28.png` shows that the brightness jump is aligned with the boundary between the left and right bar surfaces, which indicates that the root cause is the composition boundary between two neighboring transparent or blurred layer surfaces.

This design replaces the split background approach with a single full-width backdrop surface.
The left and right bar surfaces remain responsible for content only.

## Problem Statement

Current behavior:

- `leftPanel` and `rightPanel` both participate in drawing the bar background.
- `shadowPanel`, `seamPanel`, and earlier diagonal backdrop logic attempted to smooth the transition between those halves.
- Even after removing those explicit transition effects, a visible seam remains at the midpoint of the screen.

Observed root cause:

- The visible artifact is not primarily caused by the seam shader anymore.
- The artifact is caused by the compositor handling two adjacent semi-transparent or blurred layer surfaces separately.
- As long as the bar background is split across separate surfaces, the center boundary can remain visible.

## Goals

- Remove the visible center seam at the join between the left and right bar sections.
- Keep the bar semi-transparent.
- Preserve the existing workspace-dependent alpha behavior controlled by `rootScope.isTerminalWs`.
- Preserve left and right content layout and interaction behavior.
- Avoid changing the visible content arrangement unless needed to support the unified background.

## Non-Goals

- Redesign widget layout or bar content structure.
- Change the blur policy for unrelated layer surfaces.
- Reintroduce seam shaders or decorative midpoint effects.
- Remove workspace-dependent opacity behavior.

## Recommended Approach

Introduce one dedicated full-width backdrop `PanelLayer` for the bar.

That layer becomes the only surface responsible for:

- bar backdrop color
- bar backdrop opacity
- compositor blur or glass treatment associated with the bar namespace

The existing `leftPanel` and `rightPanel` remain in place for:

- widget content
- input regions and hover tracking
- tray hotzones
- content-specific clipping that is local to one side and does not define the shared center background

## Architecture

### 1. Shared Backdrop Layer

Add or repurpose a single `PanelLayer` that:

- spans the full monitor width
- has the bar height
- sits beneath the content panels
- uses one namespace for the unified bar backdrop surface

This layer draws a simple uniform rectangular backdrop across the full width.

Opacity behavior remains:

- terminal workspace: `Theme.panelSeamOpacity`
- non-terminal workspace: `Theme.panelSeamOpacity * <existing non-terminal factor>`

The intent is to preserve current transparency semantics while moving them to a single compositor surface.

### 2. Left and Right Content Panels

Keep `leftPanel` and `rightPanel`, but remove their responsibility for drawing the shared background.

They should remain responsible only for:

- content geometry
- content rendering
- pointer handling
- side-specific overlays

Any remaining backdrop-like elements inside these panels must not create a full shared background or midpoint transition.

### 3. Seam and Transition Layers

`seamPanel` and `shadowPanel` should not participate in center-join rendering anymore.

Expected end state:

- no seam-specific midpoint fill
- no shadow-based midpoint transition surface
- no diagonal midpoint mask whose purpose is to hide the join between halves

## Namespace and Blur Policy

The repository already contains blur and glass rules for `qs-panel`.

Implementation should align the unified backdrop surface with that namespace so that:

- blur or glass is applied to the single shared backdrop surface
- the content-only side panels do not need to define the shared visual background

If namespace reuse is not sufficient, the implementation may rename only the backdrop layer namespace, while keeping the existing content namespaces untouched.

## Data Flow

1. Workspace state determines whether terminal-specific opacity or non-terminal opacity is used.
2. Shared backdrop layer computes one alpha value for the whole bar surface.
3. Shared backdrop layer paints one uniform rectangle across the full width.
4. Left and right content panels render on top without contributing to the shared midpoint background.

## Error Handling and Fallbacks

- If the shared backdrop layer cannot be shown, bar content should still remain visible.
- If a side panel has no content, the shared backdrop should still remain visually correct.
- Geometry readiness logic should not gate the shared backdrop in a way that reintroduces midpoint flashing.

The backdrop should prefer stable always-on geometry over conditional midpoint calculations.

## Testing Strategy

Manual verification is the main acceptance path for this visual issue.

Required checks:

- inspect a screenshot at the center of the screen and confirm there is no brightness discontinuity at the midpoint
- verify the bar remains semi-transparent
- verify terminal and non-terminal workspaces still use different opacity behavior if currently configured
- verify left and right widgets still render and respond normally
- verify tray hover and popup behavior still work

Optional numeric verification:

- sample pixels around the center x-coordinate and confirm there is no abrupt luminance jump caused by separate backdrop surfaces

## Acceptance Criteria

- No visible seam remains at the center of the bar.
- The bar still looks uniformly semi-transparent.
- Workspace-dependent alpha behavior is preserved.
- Existing bar content and interactions continue to work.
- The midpoint no longer depends on seam-specific auxiliary surfaces.

## Risks

- Content panels may still carry local transparency or blur behavior that accidentally reintroduces a visible boundary.
- Layer ordering may need adjustment so the shared backdrop remains below content but above reserve-only layers.
- Existing namespace-based blur rules may require a small follow-up adjustment if the compositor applies blur differently to the unified layer than expected.

## Implementation Notes

- Prefer minimal changes inside `Bar.qml`.
- Reuse existing panel opacity logic instead of introducing new configuration keys.
- Avoid preserving unused seam geometry calculations if they no longer serve any rendering path.
- Do not change unrelated widget behavior while performing the backdrop unification.
