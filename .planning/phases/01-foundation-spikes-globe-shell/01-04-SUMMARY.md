---
phase: 01-foundation-spikes-globe-shell
plan: 04
subsystem: globe-interactions
tags: [realitykit, swiftui, sheets, navigation, infra-02, globe, pinpoints, spatial-tap]

# Dependency graph
requires: [01-01, 01-03]
provides:
  - GlobePinpoint — stub trip data (5 cities), spherePosition(), createEntity() with 44pt hit area
  - GlobeViewModel additions — focusedCountryCode, showPinpoints, selectedTrip, showProfileSheet, animateToCountry()
  - GlobeView additions — SpatialTapGesture (pinpoint tap + globe tap), pinpoint entity management, ProfileSheet .sheet() slot
  - ProfileSheet — primary bottom sheet with stub trip cards, nested TripDetailSheet .sheet() (INFRA-02)
  - TripDetailSheet — secondary bottom sheet with city header, stub stats, "No stops recorded" empty state
affects:
  - 02+ (all phases — ProfileSheet and TripDetailSheet are the canonical navigation pattern)

# Tech tracking
tech-stack:
  added:
    - SpatialTapGesture (.targetedToAnyEntity()) — RealityKit entity tap detection in SwiftUI RealityView
    - CollisionComponent (manual) — used instead of generateCollisionShapes for pinpoints (larger hit sphere)
  patterns:
    - Nested .sheet() pattern (INFRA-02): second sheet attached inside first sheet's body, not as sibling
    - addedPinpointIDs @State Set — dedup guard for RealityView update closure entity insertion
    - animateToCountry(): withAnimation(.easeInOut(duration: 0.6)) on rotationX/Y/cameraDistance

key-files:
  created:
    - Nomad/Globe/GlobePinpoint.swift
    - Nomad/Sheets/ProfileSheet.swift
    - Nomad/Sheets/TripDetailSheet.swift
  modified:
    - Nomad/Globe/GlobeView.swift
    - Nomad/Globe/GlobeViewModel.swift
    - Nomad.xcodeproj/project.pbxproj

key-decisions:
  - "Globe tap uses facing-direction approximation (rotationX/Y) instead of 3D raycast — SpatialTapGesture.Value only exposes 2D CGPoint; full raycast deferred to Phase 2"
  - "Pinpoint collision shape set manually via CollisionComponent (radius 0.022) rather than generateCollisionShapes — ensures 44pt hit area independent of visual sphere size"
  - "addedPinpointIDs @State Set used in RealityView update closure to prevent duplicate entity insertion on repeated renders"

# Metrics
duration: 5min
completed: 2026-04-04T23:28:00Z
---

# Phase 01 Plan 04: Globe Interactions & Stacked Sheet Navigation Summary

GlobePinpoint entities on sphere surface at lat/lon, SpatialTapGesture wiring country focus animation and pinpoint-to-sheet navigation, ProfileSheet + TripDetailSheet nested sheet pattern (INFRA-02) with PanelGradient and AppFont applied throughout — building cleanly on iOS 18 simulator.

## Performance

- **Duration:** 5 min
- **Started:** 2026-04-04T23:20:19Z
- **Completed:** 2026-04-04T23:28:00Z
- **Tasks completed:** 2 (Task 3 is checkpoint — awaiting human verification)
- **Files created:** 3
- **Files modified:** 3

## Accomplishments

- Created GlobePinpoint.swift: StubTrip data (5 cities: Tokyo JP, Paris FR, Nairobi KE, Sydney AU, Rio BR), spherePosition() lat/lon → SIMD3<Float> converter, createEntity() producing amber unlit sphere with 44pt collision shape
- Updated GlobeViewModel: focusedCountryCode/showPinpoints/selectedTrip/showProfileSheet state, tripsByCountry computed property, animateToCountry() with 600ms ease-in-out animation to country centroid
- Updated GlobeView: SpatialTapGesture targeting any entity (pinpoint tap → ProfileSheet, globe tap → animateToCountry via facing-direction approximation), pinpoint entity insertion in update closure with addedPinpointIDs dedup, first .sheet() slot for ProfileSheet
- Created ProfileSheet: "Your Journeys" header (AppFont.title, amber), "5 countries visited" caption, ScrollView of TripCard rows, panelGradient(), presentationDetents([.medium, .large]), NESTED .sheet(isPresented: $showTripDetail) for TripDetailSheet
- Created TripDetailSheet: city name header (AppFont.title, amber), dateLabel body text, divider, stub stats (Steps/Distance/Places), "No stops recorded" empty state, panelGradient(), presentationDetents([.large])
- Project builds cleanly — BUILD SUCCEEDED with zero errors

## Task Commits

1. **Task 1: GlobePinpoint entity, country focus animation, pinpoint tap gesture** — `ed67ec4` (feat)
2. **Task 2: ProfileSheet and TripDetailSheet with nested sheet pattern (INFRA-02)** — `efa5e97` (feat)

## Files Created/Modified

- `Nomad/Globe/GlobePinpoint.swift` — GlobePinpoint struct with StubTrip (5 hardcoded trips), spherePosition(), createEntity() with CollisionComponent
- `Nomad/Globe/GlobeView.swift` — SpatialTapGesture added, pinpoint entity management in update closure, ProfileSheet .sheet() slot, addedPinpointIDs @State
- `Nomad/Globe/GlobeViewModel.swift` — focusedCountryCode, showPinpoints, selectedTrip, showProfileSheet, tripsByCountry, animateToCountry() added
- `Nomad/Sheets/ProfileSheet.swift` — Primary sheet with TripCard list, nested TripDetailSheet .sheet(), panelGradient(), AppFont throughout
- `Nomad/Sheets/TripDetailSheet.swift` — Secondary sheet with StatItem components, panelGradient(), AppFont throughout
- `Nomad.xcodeproj/project.pbxproj` — Sheets group added, 3 new file references + build file entries added

## Decisions Made

- **Globe tap uses facing-direction approximation:** `SpatialTapGesture.Value` only exposes `location: CGPoint` (2D screen space) — no `location3D` property exists on iOS. Full 3D raycast hit detection requires a different approach (e.g., `ARView.hitTest` or custom ray projection). For Phase 1 spike, we approximate the tapped country by finding the visited country centroid nearest to the current globe facing direction (derived from rotationX/Y). This validates the animation mechanic. Full hit accuracy deferred to Phase 2.
- **Manual CollisionComponent for pinpoints:** `generateCollisionShapes(recursive: false)` creates a collision shape matching the visual mesh radius (0.012). We instead set a `CollisionComponent` with radius 0.022 explicitly to guarantee the 44pt hit area per Apple HIG, independent of visual sphere size.
- **addedPinpointIDs @State flag:** RealityView update closure fires on every state change. Without a dedup guard, pinpoint entities would be re-added on every rotation gesture. The Set tracks IDs already inserted; cleared when switching country focus.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `value.location3D` does not exist on `SpatialTapGesture.Value` (iOS)**
- **Found during:** Task 1 first build attempt
- **Issue:** Plan action code referenced `value.location3D` on `EntityTargetValue<SpatialTapGesture.Value>`. The `EntityTargetValue` type uses `@dynamicMemberLookup` forwarding to `SpatialTapGesture.Value`, which only has `location: CGPoint`. No `location3D` property exists in the iOS 18 SDK.
- **Fix:** Replaced 3D hit position extraction with a facing-direction approximation using current `rotationX`/`rotationY` state. Finds the visited country centroid nearest to the globe's current facing direction instead of the precise tap point.
- **Files modified:** Nomad/Globe/GlobeView.swift
- **Commit:** ed67ec4

## Known Stubs

- `Nomad/Globe/GlobePinpoint.swift` — 5 hardcoded StubTrip entries (Tokyo, Paris, Nairobi, Sydney, Rio). Marked `// STUB: Phase 1 only`. Replaced by Firestore trip models in Phase 2+.
- `Nomad/Globe/GlobeView.swift` — Globe tap uses facing-direction approximation rather than precise raycast hit detection. Functional for Phase 1 spike validation; accurate hit detection deferred to Phase 2.
- `Nomad/Sheets/ProfileSheet.swift` — "5 countries visited" is hardcoded copy per UI-SPEC Copywriting Contract. Real count from user data model in Phase 2+.
- `Nomad/Sheets/TripDetailSheet.swift` — Stats (12,450 steps, 8.3 km, 6 places) are hardcoded stub values per Phase 1 scope.

## Checkpoint: Task 3 Awaiting Human Verification

Task 3 is a `checkpoint:human-verify` gate. The executor has paused here per plan. The user must build and run the app on simulator to verify the complete interaction flow before this plan is declared complete.

See checkpoint report below for exact verification steps.

## Self-Check

### Created files exist
- Nomad/Globe/GlobePinpoint.swift: FOUND
- Nomad/Sheets/ProfileSheet.swift: FOUND
- Nomad/Sheets/TripDetailSheet.swift: FOUND

### Commits exist
- ed67ec4 (Task 1): FOUND
- efa5e97 (Task 2): FOUND

## Self-Check: PASSED

---
*Phase: 01-foundation-spikes-globe-shell*
*Completed (Tasks 1-2): 2026-04-04T23:28:00Z*
*Task 3: awaiting human verification*
