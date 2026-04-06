---
phase: 02-data-auth-foundation
plan: "04"
subsystem: place-categorization-trip-finalization
tags: [mapkit, poi, firestore, swiftdata, corelocation, route-simplification, batch-write]

dependency_graph:
  requires:
    - RoutePoint (SwiftData model from Plan 01)
    - FirestoreSchema (type-safe paths from Plan 01)
    - RouteSimplifier (RDP simplification from Plan 03)
  provides:
    - PlaceCategoryService (MKLocalPointsOfInterestRequest POI lookup with coordinate cache and 6-dimension mapping)
    - TripService (Firestore trip finalization pipeline — trip doc + routePoints batch write)
  affects:
    - Phase 3 trip detail view (reads trip doc fields written by TripService)
    - Phase 4 archetype system (reads placeCounts from trip docs)

tech-stack:
  added:
    - MKLocalPointsOfInterestRequest + MKLocalSearch (MapKit POI query API)
    - CLGeocoder.reverseGeocodeLocation (country code detection)
    - Firestore WriteBatch (400-op chunked route point writes)
  patterns:
    - Swift actor for shared mutable cache (PlaceCategoryService uses actor isolation for thread-safe cache)
    - Sample-every-N strategy for POI categorization (every 20th GPS point, avoids excessive API calls)
    - 3-point geocoding sample (start/mid/end) minimizes CLGeocoder calls for country detection

key-files:
  created:
    - Nomad/Data/PlaceCategoryService.swift
    - Nomad/Data/TripService.swift
  modified:
    - Nomad.xcodeproj/project.pbxproj (Data group + Sources build phase entries added)

key-decisions:
  - "Used Swift actor for PlaceCategoryService to make coordinate cache safe under concurrency"
  - "Sample every 20th GPS point for POI categorization (not every point) to stay within MapKit rate limits"
  - "Reverse-geocode only 3 points (start/mid/end) for country codes — CLGeocoder rate limit awareness"
  - "400-op batch size for routePoints (not 500) to maintain safe margin below Firestore limit"

patterns-established:
  - "actor pattern for shared mutable cache: PlaceCategoryService cache is actor-isolated [String: [String: Int]]"
  - "sampleStopCoordinates(every: N) pattern: reusable for any GPS-sampled POI query"

requirements-completed: [PLACE-01, PLACE-02, PLACE-03, PLACE-04]

duration: 15min
completed: "2026-04-05"
---

# Phase 02 Plan 04: Place Categorization & Trip Finalization Summary

**MKLocalPointsOfInterestRequest POI categorization with coordinate-keyed actor cache mapping 30 categories to 6 dimensions, and Firestore trip finalization pipeline writing all D-14 denormalized fields plus batch routePoints sync in 400-op chunks.**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-04-05T21:47:00Z
- **Completed:** 2026-04-05T21:49:00Z
- **Tasks:** 2
- **Files modified:** 3 (2 created, 1 modified)

## Accomplishments

- `PlaceCategoryService`: Swift actor with `MKLocalPointsOfInterestRequest`-backed POI lookup, 2-decimal coordinate cache key (~1.1km grid), 200ms rate-limit delay, and `categorizeStops` that aggregates dimension counts across multiple GPS coordinates
- `TripService`: `@MainActor final class` orchestrating the complete trip-end pipeline — RDP simplification via `RouteSimplifier`, POI categorization via `PlaceCategoryService`, 3-point CLGeocoder country detection, single-call Firestore `setData` with all D-14 fields, and chunked `syncRoutePoints` batch writer
- Both files registered in `project.pbxproj` (PBXBuildFile, PBXFileReference, Data group children, Sources build phase)

## Task Commits

1. **Task 1: PlaceCategoryService with MKLocalPointsOfInterestRequest and 6-dimension mapping** - `b09e1a1` (feat)
2. **Task 2: TripService for Firestore trip finalization and routePoints batch sync** - `fd59df8` (feat)

## Files Created/Modified

- `Nomad/Data/PlaceCategoryService.swift` - Swift actor; POI lookup via MKLocalPointsOfInterestRequest, coordinate-keyed cache, 30-category→6-dimension mapping, categorizeStops aggregation
- `Nomad/Data/TripService.swift` - @MainActor trip finalization: RDP simplification, POI categorization, CLGeocoder geocoding, Firestore trip doc write (D-14), 400-op batch routePoints sync, FieldValue.arrayUnion country code update
- `Nomad.xcodeproj/project.pbxproj` - Added PBXBuildFile/PBXFileReference/group/Sources entries for both new files

## Decisions Made

- Used `actor` (not `@Observable class`) for `PlaceCategoryService` because the cache is shared mutable state accessed from async contexts — actor isolation is the correct Swift 6 pattern here
- `sampleStopCoordinates(every: 20)` chosen based on trip duration math: 10-min trip at 1Hz = 600 points, /20 = 30 categorization calls with 200ms delay = 6s total — acceptable
- `detectCountryCodes` samples only 3 points (indices 0, mid, last) to stay within CLGeocoder's per-minute limit. Most trips stay within a single country so this is sufficient
- Batch size 400 (not 500) maintains a comfortable margin below Firestore's hard 500-operation-per-batch limit

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- xcodebuild target simulator `iPhone 16` unavailable on this machine (OS 26.2 SDKs installed). Used `iPhone 17` simulator instead — same build target, no code impact.

## Threat Surface Scan

All security mitigations from the plan's threat model were implemented:

| Threat ID | Status | Implementation |
|-----------|--------|----------------|
| T-02-14 | Mitigated | 200ms `Task.sleep` delay between sequential MKLocalSearch calls; coordinate cache eliminates redundant queries |
| T-02-15 | Accepted | Standard MapKit POI usage; no user-identifiable data in the coordinate query itself |
| T-02-16 | Mitigated | Firestore security rules (Plan 01) restrict trip document writes to authenticated owner only |

No new threat surface introduced beyond what the plan's threat model covers.

## Known Stubs

None — both services are fully wired with real data sources.

## Next Phase Readiness

- `PlaceCategoryService` and `TripService` are ready for Phase 3 integration
- Phase 3 trip-end flow calls `TripService.finalizeTrip(...)` after user stops recording
- `placeCounts` fields in Firestore trip docs are structured exactly as Phase 4's archetype engine expects (`[String: Int]` keyed by the 6 dimension names)
- `routePreview` field provides the 50-point simplified trace that Phase 3's globe card and map preview will render

## Self-Check: PASSED

Files verified:
- FOUND: Nomad/Data/PlaceCategoryService.swift
- FOUND: Nomad/Data/TripService.swift

Commits verified:
- FOUND: b09e1a1 feat(02-04): add PlaceCategoryService with MKLocalPointsOfInterestRequest and 6-dimension mapping
- FOUND: fd59df8 feat(02-04): add TripService for Firestore trip finalization and routePoints batch sync

---
*Phase: 02-data-auth-foundation*
*Completed: 2026-04-05*
