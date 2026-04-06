---
phase: 02-data-auth-foundation
plan: "01"
subsystem: auth-data-foundation
tags: [auth, firebase, swiftdata, firestore, security-rules]
dependency_graph:
  requires: []
  provides:
    - AuthManager (auth state management for all Phase 2 plans)
    - UserService (handle uniqueness check, user doc CRUD)
    - RoutePoint (SwiftData model for GPS buffering)
    - TripLocal (SwiftData model for local trip state)
    - FirestoreSchema (type-safe path constants for all Firestore ops)
    - firestore.rules (production security rules replacing Phase 1 test mode)
  affects:
    - Nomad/App/NomadApp.swift (auth-gated root view routing)
    - Nomad/Info.plist (location, photos, background mode keys added)
tech_stack:
  added:
    - SwiftData (@Model) for local GPS and trip buffering
    - FirebaseAuth (Auth.auth().addStateDidChangeListener)
    - Observation (@Observable macro for AuthManager and UserService)
  patterns:
    - Nonisolated ListenerHandleBox wrapper to safely remove Firebase listener from deinit under Swift 6 strict concurrency
    - WriteBatch for atomic user document + username reservation
    - @MainActor final class with @Observable for SwiftUI environment injection
key_files:
  created:
    - Nomad/Auth/AuthManager.swift
    - Nomad/Auth/UserService.swift
    - Nomad/Data/Models/RoutePoint.swift
    - Nomad/Data/Models/TripLocal.swift
    - Nomad/Data/FirestoreSchema.swift
    - firestore.rules
  modified:
    - Nomad/App/NomadApp.swift
    - Nomad/Info.plist
    - Nomad.xcodeproj/project.pbxproj
decisions:
  - Used ListenerHandleBox (@unchecked Sendable nonisolated wrapper) to allow deinit to remove Firebase auth listener without violating Swift 6 @MainActor isolation
  - AuthState enum defined at file scope (not nested) so it can be referenced from NomadApp without importing AuthManager module path
  - TripLocal includes cityName, startDate, endDate, isActive, isSynced — discretionary fields chosen to cover minimum trip lifecycle state needed by Plan 04
metrics:
  duration_minutes: 25
  completed_date: "2026-04-05"
  tasks_completed: 2
  tasks_total: 2
  files_created: 6
  files_modified: 3
---

# Phase 02 Plan 01: Auth Foundation & Data Models Summary

Auth layer, SwiftData models, Firestore schema, Info.plist permission keys, and production security rules — the complete data/auth contract that Plans 02, 03, and 04 depend on.

## What Was Built

**Task 1 — AuthManager, UserService, NomadApp auth gate**

- `AuthManager`: `@Observable @MainActor final class` that registers a Firebase auth state listener on init and exposes `AuthState` (.loading / .unauthenticated / .authenticated). Swift 6 strict concurrency required a nonisolated `ListenerHandleBox` wrapper so `deinit` can safely call `removeStateDidChangeListener` without crossing the `@MainActor` boundary.
- `UserService`: `@Observable @MainActor final class` providing handle availability check (Firestore read on `usernames/{handle}`), atomic batch write for `users/{uid}` + `usernames/{handle}` documents, `updateUserOnboardingComplete` for home city fields, and `fetchUserDocument`.
- `NomadApp.swift`: replaced direct `GlobeView()` with a `@ViewBuilder` switch on `authManager.authState`. `.loading` renders `Color.Nomad.globeBackground` (silent wait, no flash). `.unauthenticated` renders `Text("Onboarding Placeholder")` (Plan 02 replaces this). `.authenticated` renders `GlobeView()`. Added `.environment(authManager)` and `.modelContainer(for: [RoutePoint.self, TripLocal.self])`.

**Task 2 — Data models, schema, Info.plist, security rules**

- `RoutePoint`: `@Model final class` with tripId, lat/lon/timestamp/accuracy/altitude, `isSynced: Bool`. Init accepts `CLLocation` directly.
- `TripLocal`: `@Model final class` with tripId, cityName, startDate, endDate?, isActive, isSynced.
- `FirestoreSchema`: `enum` with static path helpers (`userDoc`, `tripsCollection`, `tripDoc`, `routePointsCollection`, `usernameDoc`) and nested `TripFields` / `UserFields` enums for all field key constants.
- `Info.plist`: added `NSLocationAlwaysAndWhenInUseUsageDescription`, `NSLocationWhenInUseUsageDescription`, `NSPhotoLibraryUsageDescription`, and `UIBackgroundModes: [location]`.
- `firestore.rules`: production rules. `users/{userId}/**` read/write gated to `request.auth.uid == userId`. `usernames/{handle}` read/write requires `request.auth != null`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Swift 6 strict concurrency: deinit cannot access @MainActor property**
- **Found during:** Task 1 build
- **Issue:** `deinit` in `AuthManager` tried to access `listenerHandle` (a `@MainActor`-isolated stored property) from nonisolated context — Swift 6 strict concurrency error.
- **Fix:** Introduced `private final class ListenerHandleBox: @unchecked Sendable` to hold the `AuthStateDidChangeListenerHandle?`. Since the box is a reference type stored by `AuthManager` but not itself actor-isolated, `deinit` can safely reach it.
- **Files modified:** `Nomad/Auth/AuthManager.swift`
- **Commit:** 7bc95f7

## Threat Surface Scan

All security mitigations in the plan's threat model were implemented:

| Threat ID | Status | Implementation |
|-----------|--------|----------------|
| T-02-01 | Mitigated | `firestore.rules` replaces Phase 1 test mode |
| T-02-02 | Mitigated | All Firestore paths require `request.auth != null` |
| T-02-03 | Mitigated | `users/{userId}/**` restricted to owner via `request.auth.uid == userId` |
| T-02-04 | Accepted | 500ms debounce + batch write reduces race window; Cloud Function fix deferred to v2 |
| T-02-05 | Accepted | `usernames` readable by any authenticated user (low-sensitivity) |
| T-02-06 | Mitigated | Firebase SDK handles credential validation server-side |

No new threat surface introduced beyond what the plan's threat model covers.

## Known Stubs

- `NomadApp.swift` line ~24: `Text("Onboarding Placeholder")` — intentional stub for the `.unauthenticated` branch. Plan 02 replaces this with `OnboardingView()`.

## Self-Check: PASSED

Files verified:
- FOUND: Nomad/Auth/AuthManager.swift
- FOUND: Nomad/Auth/UserService.swift
- FOUND: Nomad/Data/Models/RoutePoint.swift
- FOUND: Nomad/Data/Models/TripLocal.swift
- FOUND: Nomad/Data/FirestoreSchema.swift
- FOUND: firestore.rules
- FOUND: Nomad/App/NomadApp.swift (modified)
- FOUND: Nomad/Info.plist (modified)

Commits verified:
- FOUND: 7bc95f7 feat(02-01): add AuthManager, UserService, and auth-gated root view
- FOUND: fe840b1 feat(02-01): add SwiftData models, FirestoreSchema, Info.plist keys, and security rules
