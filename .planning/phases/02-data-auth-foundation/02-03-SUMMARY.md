---
phase: 02-data-auth-foundation
plan: "03"
subsystem: location-pipeline
tags: [location, gps, background-recording, route-simplification, geofence, notifications]
dependency_graph:
  requires:
    - RoutePoint (SwiftData model from Plan 01)
    - TripLocal (SwiftData model from Plan 01)
  provides:
    - LocationManager (background GPS recording with CLBackgroundActivitySession)
    - VisitMonitor (CLVisit + geofence exit trip auto-detection)
    - RouteSimplifier (RDP GPS trace simplification)
  affects:
    - Nomad/Location/ (new directory)
tech_stack:
  added:
    - CLBackgroundActivitySession (iOS 17+ background GPS session management)
    - CLLocationUpdate.liveUpdates() (iOS 17+ async GPS stream)
    - CLCircularRegion + CLVisit (geofence + visit-based trip detection)
    - UNUserNotificationCenter (local notifications for trip prompts)
  patterns:
    - CLBackgroundActivitySession as strong stored property (not local var) to prevent silent stop
    - nonisolated CLLocationManagerDelegate callbacks dispatched to MainActor via Task
    - Ramer-Douglas-Peucker recursive algorithm with CLLocation.distance(from:) Haversine metric
key_files:
  created:
    - Nomad/Location/LocationManager.swift
    - Nomad/Location/VisitMonitor.swift
    - Nomad/Location/RouteSimplifier.swift
  modified:
    - Nomad.xcodeproj/project.pbxproj (Location group + 3 file entries added)
decisions:
  - CLBackgroundActivitySession must be a stored class property — local var causes silent GPS stop on deallocation
  - CLLocationUpdate.liveUpdates() preferred over CLLocationManager delegate for iOS 17+ async pattern
  - VisitMonitor dispatches nonisolated delegate callbacks to MainActor via Task block
  - RouteSimplifier uses CLLocation.distance(from:) for meter-accurate perpendicular distance (Haversine)
metrics:
  duration_minutes: 30
  completed_date: "2026-04-05"
  tasks_completed: 2
  tasks_total: 2
  files_created: 3
  files_modified: 1
---

# Phase 02 Plan 03: Location Pipeline (GPS Recording, Trip Detection, Route Simplification) Summary

Background GPS recording via CLBackgroundActivitySession + SwiftData writes, home city geofence exit detection via CLCircularRegion + CLVisit, and Ramer-Douglas-Peucker route simplification producing detail (~500pt, 10m epsilon) and preview (~50pt, 50m epsilon) arrays ready for Firestore.

## What Was Built

**Task 1 — LocationManager with CLBackgroundActivitySession and SwiftData writes**

- `LocationManager`: `@Observable @MainActor final class` wrapping the iOS 17+ `CLLocationUpdate.liveUpdates()` async stream. Retains `CLBackgroundActivitySession` as a stored property for the entire recording lifetime — critical since deallocation silently stops background GPS.
- GPS accuracy filter: only points with `horizontalAccuracy > 0 && horizontalAccuracy < 50` are accepted, reducing battery drain from low-quality fixes (mitigates T-02-12).
- Each valid GPS update inserts a `RoutePoint` into SwiftData on `@MainActor` with `isSynced = false`.
- `fetchUnsyncedPoints(tripId:)` and `markPointsSynced(_:)` provide the interface for Plan 04's Firestore batch upload.
- `configure(modelContext:)` injection pattern follows Plan 01's single ModelContainer architecture.

**Task 2 — VisitMonitor and RouteSimplifier**

- `VisitMonitor`: `@Observable @MainActor final class NSObject` implementing `CLLocationManagerDelegate`. Sets up a `CLCircularRegion` (50km default radius) with `notifyOnExit = true` and `notifyOnEntry = false`. Registers for `startMonitoringVisits()` to catch `CLVisit` departure events. Both geofence exit and CLVisit departure dispatch to `handleGeofenceExit()` via `Task { @MainActor in }` from nonisolated delegate callbacks. Sends `UNMutableNotificationContent` ("Adventure detected!") immediately on departure. Reads `UserDefaults.standard.string(forKey: "discoveryScope")` for scope awareness (Phase 3 adds the 3-dismiss counter logic).
- `RouteSimplifier`: Pure `enum` namespace implementing Ramer-Douglas-Peucker recursively. Uses `CLLocation.distance(from:)` for meter-accurate perpendicular distance (Haversine, not Euclidean). `simplifyRoute(_ rawPoints: [RoutePoint])` returns `(detail: [[Double]], preview: [[Double]])` with epsilon 10m (~500pt) and epsilon 50m (~50pt) respectively — arrays are `[[lat, lon]]` ready for Firestore `routeDetail`/`routePreview` fields.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocker] Onboarding stub screens needed to unblock build**
- **Found during:** Task 1 verification build
- **Issue:** NomadApp.swift (modified by parallel agent 02-02) referenced `OnboardingView` which in turn referenced 5 screens not yet created (HandleScreen, LocationPermissionScreen, PhotosPermissionScreen, DiscoveryScopeScreen, HomeCityScreen). Build failed with "cannot find 'OnboardingView' in scope".
- **Fix:** Created minimal stub view files for the 5 missing screens so the build could proceed. These were subsequently replaced by the 02-02 agent with full implementations during parallel execution.
- **Files modified:** `Nomad/Onboarding/HandleScreen.swift`, `LocationPermissionScreen.swift`, `PhotosPermissionScreen.swift`, `DiscoveryScopeScreen.swift`, `HomeCityScreen.swift` (stubs, overwritten by 02-02)
- **Commit:** b95f9e2 (stub creation enabled LocationManager commit to verify)

**2. [Rule 3 - Blocker] project.pbxproj pre-registered Location group but VisitMonitor/RouteSimplifier entries missing**
- **Found during:** Task 2
- **Issue:** The HEAD commit's project.pbxproj already had the Location group with LocationManager registered (from planning scaffolding), but VisitMonitor and RouteSimplifier were not yet registered.
- **Fix:** Added PBXBuildFile, PBXFileReference, group children, and Sources build phase entries for both files.
- **Files modified:** `Nomad.xcodeproj/project.pbxproj`
- **Commit:** 79bf314

## Known Stubs

- `VisitMonitor.handleGeofenceExit()` reads `discoveryScope` but doesn't yet implement the 3-dismiss counter guard — `_ = scope` placeholder. Phase 3 (TRIP-03) will add dismiss counting logic.

## Threat Surface Scan

All security mitigations from the plan's threat model were implemented:

| Threat ID | Status | Implementation |
|-----------|--------|----------------|
| T-02-11 | Accepted | GPS data in SwiftData — local device sandbox, no server exposure until Plan 04 sync |
| T-02-12 | Mitigated | `horizontalAccuracy < 50` filter reduces spurious fixes; background session made visible via CLBackgroundActivitySession (system shows location indicator) |
| T-02-13 | Accepted | CLLocationManager events are OS-controlled — GPS spoofing requires jailbreak, out of scope for v1 |

No new threat surface introduced beyond what the plan's threat model covers.

## Self-Check: PASSED

Files verified:
- FOUND: Nomad/Location/LocationManager.swift
- FOUND: Nomad/Location/VisitMonitor.swift
- FOUND: Nomad/Location/RouteSimplifier.swift

Commits verified:
- FOUND: b95f9e2 feat(02-03): add LocationManager with CLBackgroundActivitySession and SwiftData writes
- FOUND: 79bf314 feat(02-03): add VisitMonitor, RouteSimplifier, and register Location files in Xcode project
