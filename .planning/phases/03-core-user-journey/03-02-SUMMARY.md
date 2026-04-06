---
phase: 03-core-user-journey
plan: "02"
subsystem: profile-panel
tags: [profile-sheet, drag-strip, route-preview, trip-cards, navigation, passport-stub]
dependency_graph:
  requires: [03-01]
  provides: [DragStrip, RoutePreviewPath, ProfileSheet-v2, TravelerPassportStub]
  affects: [GlobeView, all Phase 3 plans that present trips]
tech_stack:
  added: []
  patterns: [ScrollViewReader scroll-to-trip, SwiftUI Path coordinate normalization, nested .sheet INFRA-02, spring animation on card tap]
key_files:
  created:
    - Nomad/Components/DragStrip.swift
    - Nomad/Components/RoutePreviewPath.swift
    - Nomad/Sheets/TravelerPassportStub.swift
  modified:
    - Nomad/Sheets/ProfileSheet.swift
    - Nomad/Globe/GlobeView.swift
    - Nomad.xcodeproj/project.pbxproj
decisions:
  - "RoutePreviewPath uses GeometryReader inside card to pass actual rendered size to Path normalization — avoids hardcoding 120x48 and lets SwiftUI layout determine true dimensions"
  - "TripPreviewCard uses frame(height: 96) on outer container with padding(16) inside — total visual height 96pt per UI-SPEC with 16pt internal breathing room"
  - "DragStrip added as VStack { Spacer(); DragStrip } overlay inside GlobeView ZStack — avoids safeAreaInset complexity while always rendering above globe"
  - "onStartTrip: nil passed from GlobeView; Plan 03 will wire the recording flow closure"
  - "TripDocument.swift, DragStrip.swift, RoutePreviewPath.swift, TravelerPassportStub.swift all added to Nomad.xcodeproj/project.pbxproj (were not yet registered with Xcode build system)"
metrics:
  duration: "~30 min"
  completed: "2026-04-06"
  tasks_completed: 2
  files_changed: 6
---

# Phase 3 Plan 02: Profile Panel & Route Preview Cards Summary

Persistent DragStrip on globe opens data-driven ProfileSheet with amber SwiftUI Path route preview cards, ScrollViewReader scroll-to-trip, nested TripDetailSheet navigation, header "+" and profile buttons, and TravelerPassportStub for Phase 4.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create DragStrip component and add to GlobeView ZStack | 9948a6f | Nomad/Components/DragStrip.swift, Nomad/Globe/GlobeView.swift, Nomad.xcodeproj/project.pbxproj |
| 2 | Rebuild ProfileSheet with route preview cards, header buttons, scroll-to-trip, and Passport stub | 99d20bc | Nomad/Components/RoutePreviewPath.swift, Nomad/Sheets/ProfileSheet.swift, Nomad/Sheets/TravelerPassportStub.swift, Nomad/Globe/GlobeView.swift |

## What Was Built

**DragStrip** (`Nomad/Components/DragStrip.swift`): 44pt touch target with 1pt amber top border, `.ultraThinMaterial` + `globeBackground` at 60% opacity background, 36×4pt amber capsule handle 8pt from top. `contentShape(Rectangle())` ensures full 44pt hit area. Tap triggers `onTap` closure. Added to GlobeView ZStack via `VStack { Spacer(); DragStrip }` pattern — always visible above globe.

**RoutePreviewPath** (`Nomad/Components/RoutePreviewPath.swift`): SwiftUI `Path` drawn from `[[lat, lon]]` coordinate array. Normalizes lat/lon to `[0, size.width/height]` with Y-axis flip (lat increases upward, SwiftUI origin top-left). Guards against single-point and malformed pairs. Amber stroke 1.5pt. Uses `GeometryReader` in the card to receive actual rendered dimensions.

**ProfileSheet rebuilt** (`Nomad/Sheets/ProfileSheet.swift`):
- Accepts `trips: [TripDocument]`, `scrollToTripId: String?`, `onStartTrip: (() -> Void)?`
- Header: `person.circle` profile button (left, 44pt) + "Your Journeys" title + `plus.circle.fill` "+" button (right, 28pt amber, 44pt hit area)
- `ScrollViewReader` + `LazyVStack(spacing: 24)` trip list. `.onChange(of: scrollToTripId)` animates scroll to matching ID
- Empty state: "No trips yet." subheading + "Tap + to start recording your first trip." caption
- Card tap: spring(response: 0.4, dampingFraction: 0.85) animation sets `detailTrip` and `showTripDetail = true`
- Nested `.sheet` for `TripDetailSheet` (INFRA-02) and `.sheet` for `TravelerPassportStub`

**TripPreviewCard**: 96pt height, `warmCard` background, 16pt corner radius, 16pt padding. HStack: 120×48 route strip (globe-dark bg, amber Path) + VStack (city name/date/distance+steps). Distance formatted as "4.2 km . 6,200 steps".

**TravelerPassportStub** (`Nomad/Sheets/TravelerPassportStub.swift`): `panelGradient()` panel, "Passport coming soon." centered in subheading font, `.large` detent. Satisfies PANEL-06.

**GlobeView updated**: `ProfileSheet(trips:scrollToTripId:onStartTrip:)` call updated with `onStartTrip: nil` — Plan 03 wires the recording closure.

**Xcode project**: Added Components group with DragStrip.swift and RoutePreviewPath.swift. Added TripDocument.swift to Models group (was missing from 03-01 pbxproj update). Added TravelerPassportStub.swift to Sheets group. All four files registered in PBXSourcesBuildPhase.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] TripDocument.swift and new files not registered in Xcode project**
- **Found during:** Task 1 build verification
- **Issue:** Build failed with "cannot find type TripDocument in scope" because TripDocument.swift (created in 03-01) was never added to Nomad.xcodeproj/project.pbxproj. Same issue would affect DragStrip, RoutePreviewPath, TravelerPassportStub.
- **Fix:** Added PBXBuildFile, PBXFileReference, and group membership entries for all four new files in project.pbxproj. Created Components group in Xcode navigator.
- **Files modified:** Nomad.xcodeproj/project.pbxproj
- **Commit:** 9948a6f (project entries), 99d20bc (files themselves)

**2. [Rule 1 - Bug] onStartTrip parameter added in two stages**
- **Found during:** Task 1
- **Issue:** GlobeView initially called `ProfileSheet(trips:scrollToTripId:onStartTrip:)` before ProfileSheet had that parameter, causing a nil-context compile error.
- **Fix:** Removed `onStartTrip: nil` from GlobeView during Task 1 build; re-added it after Task 2 rebuilt ProfileSheet with the correct signature.
- **Files modified:** Nomad/Globe/GlobeView.swift

**3. [Rule 3 - Blocking] GoogleService-Info.plist missing in worktree**
- **Found during:** Task 1 first build attempt
- **Issue:** Xcode project referenced `Nomad/GoogleService-Info.plist` but worktree didn't have the file (gitignored credential file not in git history).
- **Fix:** Copied from parent repo working tree `/Users/shrey/nomad-final/nomadv2/Nomad/GoogleService-Info.plist`.
- **Files modified:** Nomad/GoogleService-Info.plist (not committed — gitignored)

## Known Stubs

- **TravelerPassportStub.swift** — "Passport coming soon." text. Intentional per PANEL-06; full Traveler Passport is Phase 4 scope. Does not block this plan's goal.
- **ProfileSheet.onStartTrip** — wired as `nil` from GlobeView. Plan 03 connects the recording flow closure.

## Threat Surface

No new network endpoints, auth paths, file access patterns, or schema changes introduced. All data displayed in ProfileSheet is already fetched via authenticated Firestore reads (03-01). Matches T-03-04 and T-03-05 dispositions (both `accept`).

## Self-Check: PASSED

- `Nomad/Components/DragStrip.swift` — FOUND
- `Nomad/Components/RoutePreviewPath.swift` — FOUND
- `Nomad/Sheets/ProfileSheet.swift` (TripDocument, RoutePreviewPath, onStartTrip) — FOUND
- `Nomad/Sheets/TravelerPassportStub.swift` — FOUND
- `Nomad/Globe/GlobeView.swift` (DragStrip in ZStack, onStartTrip: nil) — FOUND
- Commit 9948a6f — FOUND
- Commit 99d20bc — FOUND
- Build: SUCCEEDED
