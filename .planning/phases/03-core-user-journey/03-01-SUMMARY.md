---
phase: 03-core-user-journey
plan: "01"
subsystem: data-globe
tags: [firestore, trip-model, globe, environment-injection, live-data]
dependency_graph:
  requires: [02-data-auth-foundation]
  provides: [TripDocument, GlobeViewModel.trips, GlobeViewModel.visitedCountryCodes, LocationManager-env, VisitMonitor-env]
  affects: [GlobeView, ProfileSheet, TripDetailSheet, all Phase 3 plans]
tech_stack:
  added: [FirebaseAuth (GlobeViewModel)]
  patterns: [manual Firestore decoding via QueryDocumentSnapshot, @Observable environment injection, UIViewRepresentable coordinator diffing]
key_files:
  created:
    - Nomad/Data/Models/TripDocument.swift
  modified:
    - Nomad/Data/TripService.swift
    - Nomad/Globe/GlobeViewModel.swift
    - Nomad/Globe/GlobeView.swift
    - Nomad/App/NomadApp.swift
    - Nomad/Sheets/ProfileSheet.swift
    - Nomad/Sheets/TripDetailSheet.swift
decisions:
  - "fetchVisitedCountryCodes reads 'visitedCountryCodes' field directly (string literal) — no TripFields constant exists for user-doc fields, and UserFields enum in FirestoreSchema does not include visitedCountryCodes"
  - "GlobeView.updateUIView diffs visitedCountryCodes Set and trip count to avoid redundant overlay/annotation recreation on every SwiftUI update pass"
  - "LocationManager.configure(modelContext:) called in GlobeView .task after loadGlobeData() — GlobeView is the first view with @Environment(\.modelContext) access post-auth"
metrics:
  duration: "~25 min"
  completed: "2026-04-06"
  tasks_completed: 2
  files_changed: 6
---

# Phase 3 Plan 01: Data Foundation & Globe Live Wiring Summary

TripDocument model with manual Firestore decoding, GlobeViewModel wired to real Firestore trip and visitedCountryCodes data, LocationManager/VisitMonitor environment-injected from NomadApp, globe overlays and pinpoints replaced from hardcoded stubs to live data.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create TripDocument model and add fetchTrips to TripService | e8b765a | Nomad/Data/Models/TripDocument.swift, Nomad/Data/TripService.swift |
| 2 | Wire GlobeViewModel to Firestore, inject environment, replace globe stubs | 095b1e6 | Nomad/Globe/GlobeViewModel.swift, Nomad/Globe/GlobeView.swift, Nomad/App/NomadApp.swift, Nomad/Sheets/ProfileSheet.swift, Nomad/Sheets/TripDetailSheet.swift |

## What Was Built

**TripDocument** (`Nomad/Data/Models/TripDocument.swift`): Identifiable struct with all FirestoreSchema.TripFields fields. Snapshot initializer returns nil on missing required fields (cityName, startDate, endDate, routePreview). Memberwise initializer for previews. Derived `coordinate` computed property extracts first routePreview point as CLLocationCoordinate2D for pinpoint placement.

**TripService extensions**: `fetchTrips(userId:)` fetches trips collection ordered by startDate descending; `fetchVisitedCountryCodes(userId:)` fetches from user document. Both scoped to caller-provided userId (enforced to be Auth.auth().currentUser?.uid at call site).

**GlobeViewModel** rewritten: `trips: [TripDocument]`, `visitedCountryCodes: [String]`, `scrollToTripId: String?` replace StubTrip references. `loadGlobeData()` fetches from Firestore after GeoJSON load, gated on Auth.auth().currentUser?.uid. `animateToCountry(code:)` finds trip by visitedCountryCodes membership and sets scrollToTripId.

**GlobeView.Coordinator** updated: `addCountryOverlays(to:countries:visitedCodes:)` accepts Set<String> parameter (no longer reads hardcodedVisitedCodes). `addPinpointAnnotations(to:trips:)` accepts [TripDocument] (no longer reads StubTrip.stubTrips). `updateUIView` diffs visitedCodes set and trip count — removes overlays/annotations and re-adds only when data changes. `handleTap` uses `viewModel.visitedCountryCodes` live set.

**NomadApp**: LocationManager and VisitMonitor instantiated as `@State` properties, injected via `.environment(locationManager)` and `.environment(visitMonitor)`.

**ProfileSheet / TripDetailSheet**: Both accept `TripDocument` instead of `GlobePinpoint.StubTrip`. TripCard uses DateFormatter with "MMMM yyyy" format. TripDetailSheet displays real stepCount/distanceMeters/placeCounts. Preview macros use memberwise TripDocument initializer.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing field constant] fetchVisitedCountryCodes uses string literal**
- **Found during:** Task 1
- **Issue:** `FirestoreSchema.UserFields` does not include a `visitedCountryCodes` constant; using `FirestoreSchema.UserFields.visitedCountryCodes` would not compile.
- **Fix:** Used string literal `"visitedCountryCodes"` directly in fetchVisitedCountryCodes. Noted in decisions. A future plan can add the constant to FirestoreSchema if desired.
- **Files modified:** Nomad/Data/TripService.swift

None of the plan's other steps required deviation — all changes implemented as specified.

## Known Stubs

- **TripDetailSheet.swift** — "No stops recorded" text and stub stats layout (Steps/Distance/Places shown from real TripDocument data but route stop detail is not rendered). Per plan: "Plan 04 replaces with real data." This stub is intentional and does not block the plan's goal.
- **GlobePinpoint.StubTrip.stubTrips** — definition remains in GlobePinpoint.swift for reference but is unreferenced by any active view code. No removal needed per plan.

## Threat Surface

All Firestore reads scoped to `Auth.auth().currentUser?.uid` — guard in `loadGlobeData()` returns early if no authenticated user. Matches T-03-01 mitigation.

## Self-Check: PASSED

- `Nomad/Data/Models/TripDocument.swift` — FOUND
- `Nomad/Data/TripService.swift` (fetchTrips added) — FOUND
- `Nomad/Globe/GlobeViewModel.swift` (trips, visitedCountryCodes) — FOUND
- `Nomad/Globe/GlobeView.swift` (no hardcodedVisitedCodes, no StubTrip.stubTrips) — FOUND
- `Nomad/App/NomadApp.swift` (.environment(locationManager), .environment(visitMonitor)) — FOUND
- Commit e8b765a — FOUND
- Commit 095b1e6 — FOUND
- Build: SUCCEEDED
