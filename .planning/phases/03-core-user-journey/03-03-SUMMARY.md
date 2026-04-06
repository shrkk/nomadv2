---
phase: 03-core-user-journey
plan: "03"
subsystem: trip-recording
tags: [recording-pill, trip-lifecycle, healthkit, visit-monitor, notifications, uialertcontroller]
dependency_graph:
  requires: [03-01, 03-02]
  provides: [RecordingPill, trip-start-stop-name-flow, HealthKit-step-query, VisitMonitor-dismiss-counter]
  affects: [GlobeView, VisitMonitor, AppDelegate, ProfileSheet.onStartTrip]
tech_stack:
  added: [HealthKit (HKStatisticsQuery), UserNotifications (UNUserNotificationCenterDelegate)]
  patterns: [UIAlertController-with-textfield, UNNotificationCategory-customDismissAction, @preconcurrency-protocol-conformance, conditional-ZStack-for-timer-lifecycle]
key_files:
  created:
    - Nomad/Components/RecordingPill.swift
  modified:
    - Nomad/Globe/GlobeView.swift
    - Nomad/Location/VisitMonitor.swift
    - Nomad/App/AppDelegate.swift
    - Nomad/Info.plist
    - Nomad.xcodeproj/project.pbxproj
decisions:
  - "RecordingPill removed from view hierarchy via conditional if (not opacity/zIndex toggle) when isRecording=false — ensures Timer.publish is cancelled, per T-03-09"
  - "AppDelegate uses @preconcurrency UNUserNotificationCenterDelegate to satisfy Swift 6 actor-isolation: UIApplicationDelegate is @MainActor but UNUserNotificationCenterDelegate callbacks arrive off-main; only UserDefaults writes in callbacks (thread-safe)"
  - "willPresent uses UNNotificationPresentationOptions (not UNPresentationOptions) — correct Swift 6 type name"
  - "VisitMonitor.registerNotificationCategory called in startMonitoring before first notification delivery — ensures category with .customDismissAction is registered before any dismiss event can fire"
  - "saveTrip reverse-geocodes route point sample (first/middle/last) to detect country codes for updateUserVisitedCountries — mirrors TripService.detectCountryCodes approach to avoid a second Firestore read"
  - "HealthKit capability in Signing & Capabilities requires manual Xcode step — NSHealthShareUsageDescription in Info.plist is necessary but not sufficient; entitlement must also be added"
metrics:
  duration: "~30 min"
  completed: "2026-04-06"
  tasks_completed: 2
  files_changed: 6
---

# Phase 3 Plan 03: Trip Recording Flow Summary

Complete trip recording UX: RecordingPill component with pulsing dot and elapsed timer, trip start via "+" button (UUID + LocationManager.startRecording), trip name UIAlertController dialog, TripService finalization with HealthKit step count, VisitMonitor 3-dismiss counter switching to manual-only mode, and AppDelegate notification delegate for dismiss tracking.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1a+1b | RecordingPill component, GlobeView trip wiring (start/stop/name/save/discard) | b94caf0 | Nomad/Components/RecordingPill.swift, Nomad/Globe/GlobeView.swift, Nomad.xcodeproj/project.pbxproj |
| 2 | VisitMonitor dismiss counter, AppDelegate notification delegate, Info.plist HealthKit | c6016f0 | Nomad/Location/VisitMonitor.swift, Nomad/App/AppDelegate.swift, Nomad/Info.plist |

## What Was Built

**RecordingPill** (`Nomad/Components/RecordingPill.swift`): SwiftUI view shown on globe during active recording. Pulsing red dot (PulseAnimation: scale 1.0→1.4, opacity 1.0→0.6, 2-second easeInOut cycle), elapsed timer formatted as "0m 45s" / "12m 30s" / "1h 23m", Stop Trip button in amber. Capsule background with `.thinMaterial` + `globeBackground` overlay + amber stroke. Timer increments via `Timer.publish(every: 1)` on `.onReceive`. Pill conditionally present in ZStack (`if locationManager.isRecording`) — removed from view hierarchy (not just hidden) so timer is deallocated when recording stops (T-03-09).

**GlobeView trip recording wiring**: Added `activeTripId`, `recordingStartDate`, `showNameAlert` state. ProfileSheet `onStartTrip` closure now generates UUID, calls `locationManager.startRecording(tripId:)`, dismisses sheet. `presentTripNameAlert()` presents UIAlertController with text field; Save button disabled until non-empty text via `UITextField.textDidChangeNotification` observer. `saveTrip(name:)` fetches unsynced route points, stops recording, queries HealthKit steps, calculates distance, calls `TripService.finalizeTrip`, marks points synced, reverse-geocodes sample coordinates for country codes, calls `updateUserVisitedCountries`, refreshes globe data. `discardTrip()` stops recording and purges SwiftData RoutePoints for the trip via existing `modelContext`. All three methods (`saveTrip`, `discardTrip`, `queryStepCount`, `calculateDistance`) added to GlobeView. Imports added: `FirebaseAuth`, `HealthKit`, `SwiftData`, `CoreLocation`.

**VisitMonitor** (`Nomad/Location/VisitMonitor.swift`): `handleGeofenceExit()` now guards on `UserDefaults.standard.bool(forKey: "manualOnlyMode")` — returns early if true. `registerNotificationCategory()` creates `UNNotificationCategory` with identifier `"tripPromptCategory"` and `.customDismissAction` option; called in `startMonitoring()` before notification permission request. `sendTripStartNotification()` sets `content.categoryIdentifier = "tripPromptCategory"` so dismiss events reach `AppDelegate`.

**AppDelegate** (`Nomad/App/AppDelegate.swift`): Conforms to `@preconcurrency UNUserNotificationCenterDelegate`. Sets `UNUserNotificationCenter.current().delegate = self` in `didFinishLaunchingWithOptions`. `userNotificationCenter(_:didReceive:withCompletionHandler:)` checks for `"tripStartPrompt-"` prefix, counts `UNNotificationDismissActionIdentifier` responses into `tripPromptDismissCount` UserDefaults key, sets `manualOnlyMode = true` when count reaches 3. `userNotificationCenter(_:willPresent:withCompletionHandler:)` returns `.banner` + `.sound` for foreground display.

**Info.plist**: Added `NSHealthShareUsageDescription` — "Nomad reads your step count to include walking stats in your trip summaries." Required for HKHealthStore.requestAuthorization (T-03-06).

**MANUAL STEP REQUIRED**: HealthKit capability must be enabled in Xcode → Nomad target → Signing & Capabilities → "+ Capability" → "HealthKit". This adds `com.apple.developer.healthkit` to `Nomad.entitlements`. The Info.plist key alone is not sufficient for HealthKit queries to succeed at runtime.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Swift 6 UNUserNotificationCenterDelegate actor-isolation error**
- **Found during:** Task 2 first build
- **Issue:** `class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate` produced "conformance crosses into main actor-isolated code" error in Swift 6 strict concurrency mode. Also `UNPresentationOptions` was not found — correct type is `UNNotificationPresentationOptions`.
- **Fix:** Changed to `@preconcurrency UNUserNotificationCenterDelegate` to suppress actor-crossing warning (callbacks only write to UserDefaults, which is thread-safe). Changed `UNPresentationOptions` to `UNNotificationPresentationOptions`.
- **Files modified:** Nomad/App/AppDelegate.swift
- **Commit:** c6016f0

**2. [Rule 1 - Bug] Swift 6 Sendable warning in UITextField.textDidChangeNotification callback**
- **Found during:** Task 1a build verification
- **Issue:** `alert.textFields?.first?.text` and `saveAction.isEnabled` referenced from a Sendable closure, producing Swift 6 concurrency warnings.
- **Fix:** Extracted `textField` reference before the observer, used `[weak textField]` capture, wrapped mutation in `DispatchQueue.main.async`.
- **Files modified:** Nomad/Globe/GlobeView.swift
- **Commit:** b94caf0

None of the plan's structural steps required deviation — all architecture implemented as specified.

## Known Stubs

None — all plan goals achieved. HealthKit authorization is requested at runtime on first trip save; no stub values flow to UI.

## Threat Surface

**T-03-06 (HealthKit read):** `NSHealthShareUsageDescription` added to Info.plist. `requestAuthorization(toShare: [], read: [stepType])` requests read-only access to `.stepCount` only — minimum necessary permission. No health data written. HealthKit capability entitlement requires manual Xcode step (noted above).

**T-03-07 (UserDefaults manualOnlyMode):** Accepted — local preference only, no security impact.

**T-03-08 (UIAlertController trip name):** Accepted — user names their own trip, not used for auth.

**T-03-09 (Timer.publish lifecycle):** Mitigated — RecordingPill removed from view hierarchy via `if locationManager.isRecording`, ensuring `Timer.publish` is cancelled when not recording.

No new threat surface beyond the plan's threat model.

## Self-Check: PASSED

- `Nomad/Components/RecordingPill.swift` — FOUND
- `Nomad/Globe/GlobeView.swift` (RecordingPill, saveTrip, discardTrip, queryStepCount) — FOUND
- `Nomad/Location/VisitMonitor.swift` (manualOnlyMode guard) — FOUND
- `Nomad/App/AppDelegate.swift` (tripPromptDismissCount) — FOUND
- `Nomad/Info.plist` (NSHealthShareUsageDescription) — FOUND
- Commit b94caf0 — FOUND
- Commit c6016f0 — FOUND
- Build: SUCCEEDED
