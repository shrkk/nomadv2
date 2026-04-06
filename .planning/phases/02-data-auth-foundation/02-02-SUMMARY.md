---
phase: 02-data-auth-foundation
plan: "02"
subsystem: onboarding
tags: [onboarding, firebase-auth, firestore, cllocationmanager, photos, swiftui]
dependency_graph:
  requires:
    - AuthManager (02-01)
    - UserService (02-01)
    - AppColors (01)
    - AppFont (01)
  provides:
    - OnboardingCoordinator (step state machine, accumulated data)
    - OnboardingView (paged container with transitions and progress dots)
    - WelcomeScreen (first-impression globe-dark hero)
    - SignUpScreen (Firebase Auth create/sign-in)
    - HandleScreen (debounced Firestore uniqueness check)
    - LocationPermissionScreen (two-step Always location auth)
    - PhotosPermissionScreen (PHPhotoLibrary read/write auth)
    - DiscoveryScopeScreen (awayOnly/everywhere selection)
    - HomeCityScreen (CLGeocoder detect + 50km geofence + Firestore write)
  affects:
    - Nomad/App/NomadApp.swift (replaced Text placeholder with OnboardingView, injected UserService)
tech_stack:
  added:
    - CoreLocation (CLGeocoder, CLCircularRegion geofence, CLLocationManager two-step auth)
    - Photos framework (PHPhotoLibrary.requestAuthorization)
    - FirebaseAuth (AuthErrorCode mapping in SignUpScreen)
  patterns:
    - OnboardingCoordinator @Observable state machine accumulates data across screens for single Firestore write at end
    - LocationPermissionRequester: @Observable NSObject delegate helper isolates CLLocationManager callbacks
    - OneTimeLocationDelegate: continuation-based bridge for CLLocationManager.requestLocation()
    - 500ms debounce via Task.sleep + Task.isCancelled check (T-02-10 rate limiting)
    - Two-step location auth: requestWhenInUse → requestAlways on .authorizedWhenInUse status
key_files:
  created:
    - Nomad/Onboarding/OnboardingCoordinator.swift
    - Nomad/Onboarding/OnboardingView.swift
    - Nomad/Onboarding/WelcomeScreen.swift
    - Nomad/Onboarding/SignUpScreen.swift
    - Nomad/Onboarding/HandleScreen.swift
    - Nomad/Onboarding/LocationPermissionScreen.swift
    - Nomad/Onboarding/PhotosPermissionScreen.swift
    - Nomad/Onboarding/DiscoveryScopeScreen.swift
    - Nomad/Onboarding/HomeCityScreen.swift
  modified:
    - Nomad/App/NomadApp.swift (OnboardingView replaces placeholder, UserService injected)
    - Nomad.xcodeproj/project.pbxproj (Onboarding group + 9 source files added)
decisions:
  - Used @Observable LocationPermissionRequester (NSObject subclass) to bridge CLLocationManagerDelegate into SwiftUI state
  - Used OneTimeLocationDelegate with CheckedContinuation for single location fix in HomeCityScreen
  - Removed associated object pattern (required var for & address) in favor of local CLLocationManager instance per detection call
  - .spring(duration:bounce:) used instead of deprecated .spring(dampingFraction:duration:) for iOS 26 SDK compatibility
  - UserDefaults.set(true, forKey: "onboardingComplete") written at end of HomeCityScreen as fallback for instant routing on next launch
metrics:
  duration_minutes: 9
  completed_date: "2026-04-06"
  tasks_completed: 2
  tasks_total: 2
  files_created: 9
  files_modified: 2
---

# Phase 02 Plan 02: Onboarding Flow Summary

7-screen onboarding flow (Welcome → Sign Up → Handle → Location → Photos → Discovery Scope → Home City) fully wired to AuthManager and UserService, matching the UI-SPEC design contract.

## What Was Built

**Task 1 — OnboardingCoordinator, OnboardingView, WelcomeScreen, SignUpScreen**

- `OnboardingCoordinator`: `@Observable @MainActor final class` with 7-case `OnboardingStep` enum, accumulated data fields (email, password, handle, discoveryScope, homeCityName, lat/lon), `advance()`/`goBack()` navigation, and `activeDotIndex` computed for progress dot rendering.
- `OnboardingView`: paged container switching on `coordinator.currentStep`. Horizontal spring slide transitions (`.asymmetric` insertion/removal with `.spring(duration: 0.4, bounce: 0.15)`). `isForward` state tracks direction to flip transition. Progress dots (6 dots, 8pt diameter, 4pt gap, amber active / warmCard inactive) + `chevron.left` back button (44pt hit area, 70% globeBackground) rendered as overlay on screens 2–7.
- `WelcomeScreen`: `Color.Nomad.globeBackground` full-bleed, "Nomad" title at 35% height, "The world is yours to explore." tagline, amber "Get started" CTA pinned 48pt above safe area, "Already have an account? Sign in" link.
- `SignUpScreen`: cream background, conditional header (sign-in vs create-account mode), email/password fields (warmCard, 48pt, 12pt radius), show/hide password toggle (`eye`/`eye.slash`), Firebase Auth error mapping for all `AuthErrorCode` cases, async CTA with `ProgressView` loading state.
- `NomadApp.swift`: `Text("Onboarding Placeholder")` replaced with `OnboardingView()`. `UserService` added as `@State` and injected via `.environment(userService)`.

**Task 2 — Handle, Permission, DiscoveryScope, and HomeCity screens**

- `HandleScreen`: cream background, "@" prefix TextField, `HandleState` enum (idle/checking/available/taken/invalidFormat). T-02-07: `.onChange` filtering strips non-alphanumeric/underscore, lowercases, truncates at 30 chars. T-02-10: 500ms `Task.sleep` debounce with `Task.isCancelled` guard before `userService.isHandleAvailable`. Trailing indicator (spinner/checkmark/xmark/exclamation) and inline caption. CTA calls `userService.createUserWithHandle` on `.available` state.
- `LocationPermissionScreen`: `LocationPermissionRequester` (@Observable NSObject + CLLocationManagerDelegate) handles two-step auth: `requestWhenInUseAuthorization` → `requestAlwaysAuthorization` on `.authorizedWhenInUse`. Any non-`.notDetermined` status sets `didReceiveResult = true` → coordinator advances. Never blocks on denial.
- `PhotosPermissionScreen`: `PHPhotoLibrary.requestAuthorization(for: .readWrite)` with `DispatchQueue.main.async` advance on any callback result.
- `DiscoveryScopeScreen`: two `ScopeCard` views (globe/"Everywhere" and house/"Away from home only"). `awayOnly` pre-selected. Selected card: `Color.Nomad.amber.opacity(0.1)` background + 2pt amber border. Tap animation: `.scaleEffect(0.97)` via `DragGesture`.
- `HomeCityScreen`: `CLLocationManager.requestLocation()` + `CLGeocoder.reverseGeocodeLocation` via `CheckedContinuation`-based `OneTimeLocationDelegate`. Detected city shown in warmCard confirmation card; "That's not right" link fades to edit TextField. 50km `CLCircularRegion` geofence registered on confirm (`notifyOnEntry = false, notifyOnExit = true`). `userService.updateUserOnboardingComplete` writes final Firestore doc. "Couldn't save. Tap to retry." inline error on failure. `UserDefaults` flag written as launch routing fallback.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `.spring(dampingFraction:duration:)` not available in iOS 26 SDK**
- **Found during:** Task 1 build
- **Issue:** `xcodebuild` error: "cannot call value of non-function type 'Animation'" — `Animation.spring(dampingFraction:duration:)` is not available in the iOS 26 beta SDK.
- **Fix:** Changed to `.spring(duration: 0.4, bounce: 0.15)` which is the new API and approximates damping 0.85 (low bounce).
- **Files modified:** `Nomad/Onboarding/OnboardingView.swift`
- **Commit:** 199e1af

**2. [Rule 1 - Bug] `AssociatedKey.delegateKey` mutable var needed by `objc_setAssociatedObject(&key)` conflicts with Swift 6 concurrency**
- **Found during:** Task 2 build
- **Issue:** Static `var` for associated object key is not concurrency-safe (Swift 6 strict concurrency error). Changing to `let` breaks `&` address-of usage.
- **Fix:** Eliminated the associated object pattern entirely. Used a dedicated local `CLLocationManager` instance per detection call; the `OneTimeLocationDelegate` retains itself via the manager's `delegate` property.
- **Files modified:** `Nomad/Onboarding/HomeCityScreen.swift`
- **Commit:** b46df45

## Threat Surface Scan

All threat model mitigations implemented:

| Threat ID | Status | Implementation |
|-----------|--------|----------------|
| T-02-07 | Mitigated | `HandleScreen.onChange` strips non-[a-z0-9_] chars, truncates at 30 chars before Firestore check |
| T-02-08 | Mitigated | Firebase Auth validates email/password server-side; CTA disabled until both fields non-empty |
| T-02-09 | Accepted | Handle availability probe is intentional UX; accepted per plan |
| T-02-10 | Mitigated | 500ms debounce in `HandleScreen` reduces Firestore read volume |

No new threat surface introduced beyond the plan's threat model.

## Known Stubs

None — all 9 onboarding screens are fully implemented. The previous stub in `NomadApp.swift` (`Text("Onboarding Placeholder")`) has been replaced with `OnboardingView()`.

## Self-Check: PASSED

Files verified:
- FOUND: Nomad/Onboarding/OnboardingCoordinator.swift
- FOUND: Nomad/Onboarding/OnboardingView.swift
- FOUND: Nomad/Onboarding/WelcomeScreen.swift
- FOUND: Nomad/Onboarding/SignUpScreen.swift
- FOUND: Nomad/Onboarding/HandleScreen.swift
- FOUND: Nomad/Onboarding/LocationPermissionScreen.swift
- FOUND: Nomad/Onboarding/PhotosPermissionScreen.swift
- FOUND: Nomad/Onboarding/DiscoveryScopeScreen.swift
- FOUND: Nomad/Onboarding/HomeCityScreen.swift

Commits verified:
- FOUND: 199e1af feat(02-02): add OnboardingCoordinator, OnboardingView, WelcomeScreen, SignUpScreen
- FOUND: b46df45 feat(02-02): add Handle, Permission, DiscoveryScope, and HomeCity screens
