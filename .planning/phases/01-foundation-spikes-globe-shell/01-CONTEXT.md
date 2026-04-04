# Phase 1: Foundation Spikes & Globe Shell - Context

**Gathered:** 2026-04-04
**Status:** Ready for planning

<domain>
## Phase Boundary

Validate the two highest-risk architectural unknowns — RealityKit globe renders visited-country polygons on a physical device without stutter, and stacked SwiftUI bottom sheets work reliably. Also: establish the bundled GeoJSON pipeline, connect Firebase, and lock in the design system (fonts, color palette, panel style) as reusable components. Nothing else starts until this phase proves the core architecture works.

</domain>

<decisions>
## Implementation Decisions

### Globe Environment
- **D-01:** Dark space background — deep black/navy with subtle star field. Creates a premium, immersive backdrop against which country glows read clearly.
- **D-02:** Soft directional light (warm hemisphere) — one primary light source, like a sun, casting warm glow on visible hemisphere with a soft dark side. Feels real and dramatic, not flat.

### Country Highlight Style
- **D-03:** Accent color fill with subtle outer glow — visited countries filled with the primary accent color at ~60% opacity, soft glow bleeding out 2–3px. Overlay on sphere surface.
- **D-04:** Static highlights — no animation, no pulse. Keeps the RealityKit render loop clean and avoids distraction.

### Color Palette
- **D-05:** Primary accent: warm amber/gold — `#E8A44A` or calibrated equivalent. Used for: country highlights on globe, interactive elements, buttons, key stats.
- **D-06:** Panel/background palette: warm off-whites and creams with amber tints — cream backgrounds (`#FAF8F4`), warm card surfaces (`#F5F0E8`). Cohesive with the amber accent. Editorial tone.

### Panel Gradient
- **D-07:** Warm amber-to-cream gradient bleeding in from top-left and top-right corners of each panel, fading to the cream background. Light grain texture at ~8% opacity. Handcrafted, editorial feel. Consistent across all bottom sheet panels.

### Typography Scale (AppFont)
- **D-08:** Editorial-large scale — Playfair Display for display/heading faces, Inter for body/labels:
  - `LargeTitle`: 34pt Playfair Display
  - `Title`: 28pt Playfair Display
  - `Subheading`: 20pt Playfair Display
  - `Body`: 16pt Inter
  - `Caption`: 13pt Inter

### Claude's Discretion
- Star field density and particle size on globe background
- Exact amber calibration (D-05 is a starting point; fine-tune on device)
- Grain texture implementation approach (Metal shader vs CoreImage vs image overlay)
- AppFont weight variants (regular vs semibold for each level)
- Firebase initialization error handling details

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Design system
- `.planning/REQUIREMENTS.md` §Design System (DSYS-01 through DSYS-05) — Font pairing, panel style, design-questions-first requirement
- `.planning/PROJECT.md` §Requirements (Design System section) — Non-negotiables: Playfair Display + Inter, grainy gradient panels, pastel scheme

### Infrastructure spikes
- `.planning/REQUIREMENTS.md` §Infrastructure & Spikes (INFRA-01 through INFRA-04) — Globe rendering approach, sheet navigation validation, Firebase setup, GeoJSON pipeline requirements
- `.planning/REQUIREMENTS.md` §Globe Home View (GLOBE-01 through GLOBE-05) — Globe requirements this phase must stub out

### Architecture decisions
- `.planning/STATE.md` §Key Decisions Made During Init — RealityKit (not MapKit), MKLocalPointsOfInterestRequest (not CLPlacemark), Firebase 12.x via SPM, SceneKit deprecated

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- None yet — this is the first phase, greenfield project

### Established Patterns
- SwiftUI + AppDelegate adaptor pattern for Firebase initialization (per STATE.md)
- SwiftData for local persistence (per REQUIREMENTS.md LOC-03)

### Integration Points
- Firebase AppDelegate adaptor → App struct (new, no existing code)
- AppFont type → all subsequent UI phases (downstream consumers)
- Panel gradient style → all bottom sheet panels in Phases 2–4
- GeoJSON parser → Globe view, then Passport flat map in Phase 4
- RealityKit globe entity → persistent home view that all phases overlay

</code_context>

<specifics>
## Specific Ideas

- Country highlight should feel like "glowing owned territory" — not just an outline, but clearly marked as visited. Accent fill + glow achieves this.
- Globe background echoes premium globe app aesthetics — "dark space, subtle stars" is the reference frame.
- Panel gradient: amber bleeds from corners, grain texture at ~8% opacity — feels handcrafted, not corporate.
- Typography: "Editorial-large, bold and spacious" — the Playfair Display LargeTitle at 34pt sets the editorial register that all phases inherit.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 01-foundation-spikes-globe-shell*
*Context gathered: 2026-04-04*
