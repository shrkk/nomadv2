---
phase: 03-core-user-journey
verified: 2026-04-06T00:00:00Z
status: human_needed
score: 7/7 must-haves verified (all truths confirmed; human checks remain for UI behavior)
re_verification: false
human_verification:
  - test: "Open app, log in, and tap the DragStrip at the bottom of the globe"
    expected: "ProfileSheet slides up showing real trips from Firestore (or empty state 'No trips yet.' if user has none)"
    why_human: "Cannot verify live Firestore data renders in ProfileSheet without running the app on device"
  - test: "Tap '+' in ProfileSheet header"
    expected: "ProfileSheet dismisses, RecordingPill appears at top of globe with pulsing red dot and elapsed timer counting up"
    why_human: "Timer animation and real-time display cannot be verified statically"
  - test: "With the RecordingPill active, tap 'Stop Trip', enter a name, and tap 'Save Trip'"
    expected: "Alert dismisses, pill disappears, globe refreshes (new trip pinpoint + country highlight visible)"
    why_human: "TripService.finalizeTrip + updateUserVisitedCountries + loadGlobeData chain cannot be exercised without a live Firestore backend and LocationManager producing real RoutePoints"
  - test: "Tap a trip card in ProfileSheet"
    expected: "TripDetailSheet slides up over ProfileSheet; sliding it down returns to ProfileSheet (no cascade dismissal)"
    why_human: "INFRA-02 nested sheet cascade behavior must be confirmed by hand"
  - test: "With TripDetailSheet open, wait for the 240pt MapKit map to render"
    expected: "Amber polyline trace appears; numbered amber circle pins appear in visit order"
    why_human: "Map rendering and numbered pin appearance require Firestore routePoints data and live MapKit render"
  - test: "After 3 swipe-aways of auto-detect notifications, verify no further notifications fire on geofence exit"
    expected: "VisitMonitor.handleGeofenceExit returns early (manualOnlyMode=true in UserDefaults)"
    why_human: "CLRegion monitoring and notification dismiss counting require physical device + location simulation"
---

# Phase 3: Core User Journey — Verification Report

**Phase Goal:** Assemble the full product loop: persistent profile panel with real trip history, manual + auto trip logging UX, active recording indicator, and full trip detail view with GPS trace, photo gallery, and HealthKit steps — all reading from the Phase 2 data pipeline.

**Verified:** 2026-04-06
**Status:** HUMAN_NEEDED — all code verified as substantive and wired; 6 behavioral items require device testing
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths (Roadmap Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Profile bottom sheet accessible via persistent bottom handle; real trips listed newest-first as route preview cards | VERIFIED | `DragStrip.swift` (44pt touch target, `.onTapGesture { onTap() }`), `ProfileSheet.swift` accepts `[TripDocument]` in reverse-chron order from `GlobeViewModel.loadGlobeData()` which calls `TripService.fetchTrips` with `descending: true` |
| 2 | "+" button starts trip log; recording indicator visible while recording; user can stop and name trip triggering Firestore write | VERIFIED | `GlobeView.swift`: `onStartTrip` closure generates UUID + calls `locationManager.startRecording`; `if locationManager.isRecording { RecordingPill(...) }` conditional renders/removes pill; `presentTripNameAlert()` → `saveTrip(name:)` → `TripService.finalizeTrip` |
| 3 | After 3 dismissed auto-detect prompts, switches to manual-only mode silently | VERIFIED | `AppDelegate.swift`: `didReceive response` counts `tripStartPrompt-` dismissals into `tripPromptDismissCount`, sets `manualOnlyMode=true` at count≥3. `VisitMonitor.handleGeofenceExit()` guards: `guard !UserDefaults.standard.bool(forKey: "manualOnlyMode") else { return }` |
| 4 | Trip detail panel: MapKit polyline + named place pins; stats (steps, distance, duration, places, top category); city name header | VERIFIED | `TripDetailSheet.swift`: `trip.cityName` header, `TripRouteMapContainer` at 240pt, 5-cell stats row with formatSteps/formatDistance/formatDuration/formatPlaces/topCategoryInfo. `TripRouteMapView.swift`: MKPolyline renderer + `NumberedAnnotation` with UIGraphicsImageRenderer amber circles |
| 5 | Photo gallery with PHAsset matching by date+GPS bbox; nil-location photos via date-range fallback; no main-thread blocking | VERIFIED | `PhotoGalleryStrip.swift`: `PHFetchOptions` with creationDate predicate; two-pass: GPS bbox filter for located assets, date-range-only fallback for nil-location assets; `resumed-flag` `withCheckedContinuation` pattern prevents degraded-frame hang; `MainActor.run` for final UI update |
| 6 | Globe highlights visited countries from user document; pinpoints for each trip; pinpoint tap scrolls profile panel to that trip | VERIFIED | `GlobeView.swift` Coordinator: `addCountryOverlays` uses `viewModel.visitedCountryCodes` (live); `addPinpointAnnotations` uses `[TripDocument]`; `mapView(_:didSelect:)` sets `viewModel.scrollToTripId = trip.tripID` and `viewModel.showProfileSheet = true`. `ProfileSheet` `ScrollViewReader.onChange(of: scrollToTripId)` animates scroll |
| 7 | Profile button opens Traveler Passport stub (full implementation Phase 4) | VERIFIED | `ProfileSheet.swift`: `person.circle` button sets `showPassport = true`; `.sheet(isPresented: $showPassport) { TravelerPassportStub() }`. `TravelerPassportStub.swift` renders "Passport coming soon." — intentional per PANEL-06 and Phase 4 roadmap |

**Score: 7/7 truths verified**

---

## Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `Nomad/Data/Models/TripDocument.swift` | TripDocument Identifiable struct with all Firestore fields + snapshot initializer | VERIFIED | 71 lines; snapshot initializer guards on cityName/startDate/endDate/routePreview; uses `FirestoreSchema.TripFields` constants throughout; memberwise init for previews |
| `Nomad/Data/TripService.swift` | fetchTrips + fetchVisitedCountryCodes methods | VERIFIED | `fetchTrips` orders by `startDate descending`; `fetchVisitedCountryCodes` reads user doc; both accept userId parameter enforced at call site |
| `Nomad/Globe/GlobeViewModel.swift` | Real Firestore fetch in `loadGlobeData()` | VERIFIED | `trips: [TripDocument]`, `visitedCountryCodes: [String]`, `scrollToTripId: String?` present; `loadGlobeData()` calls `tripService.fetchTrips` + `fetchVisitedCountryCodes` after GeoJSON load, gated on `Auth.auth().currentUser?.uid` |
| `Nomad/App/NomadApp.swift` | LocationManager + VisitMonitor environment injection | VERIFIED | `@State private var locationManager = LocationManager()` and `@State private var visitMonitor = VisitMonitor()` declared; `.environment(locationManager)` and `.environment(visitMonitor)` in WindowGroup chain |
| `Nomad/Globe/GlobeView.swift` | Live data wiring, RecordingPill, DragStrip, trip lifecycle | VERIFIED | 459 lines; DragStrip in ZStack; conditional `if locationManager.isRecording { RecordingPill }` (not opacity toggle); `saveTrip`/`discardTrip`/`queryStepCount`/`calculateDistance` all present; `presentTripNameAlert()` uses UIAlertController per D-05 |
| `Nomad/Components/DragStrip.swift` | Persistent bottom handle | VERIFIED | 56 lines; 44pt touch target via `contentShape(Rectangle())`; amber capsule handle, ultraThinMaterial background; `DragStrip` in GlobeView ZStack via `VStack { Spacer(); DragStrip }` |
| `Nomad/Components/RoutePreviewPath.swift` | SwiftUI Path from routePreview coordinates | VERIFIED | Coordinate normalization with Y-flip; guards against single-point and malformed pairs; amber 1.5pt stroke; used inside `TripPreviewCard` via `GeometryReader` |
| `Nomad/Sheets/ProfileSheet.swift` | Real trip list, header buttons, scroll-to-trip | VERIFIED | Accepts `trips: [TripDocument]`, `scrollToTripId: String?`, `onStartTrip: (() -> Void)?`; ScrollViewReader with `.onChange(of: scrollToTripId)` scroll animation; empty state; nested .sheet for TripDetailSheet (INFRA-02 pattern); passport .sheet |
| `Nomad/Sheets/TravelerPassportStub.swift` | Stub with "Passport coming soon." | VERIFIED | Contains "Passport coming soon." text; panelGradient, .large detent |
| `Nomad/Components/RecordingPill.swift` | Pulsing dot, elapsed timer, Stop Trip button | VERIFIED | 85 lines; PulseAnimation modifier (scale 1.0→1.4, opacity 1.0→0.6, 2s easeInOut); `Timer.publish(every: 1)` with `.onReceive`; pill removed from hierarchy via conditional `if` in GlobeView |
| `Nomad/Location/VisitMonitor.swift` | manualOnlyMode guard in handleGeofenceExit | VERIFIED | Guard present at line 82; `registerNotificationCategory()` with `.customDismissAction` called from `startMonitoring()`; `content.categoryIdentifier = "tripPromptCategory"` in `sendTripStartNotification()` |
| `Nomad/App/AppDelegate.swift` | tripPromptDismissCount notification delegate | VERIFIED | `@preconcurrency UNUserNotificationCenterDelegate`; dismiss counter increments on `UNNotificationDismissActionIdentifier`; sets `manualOnlyMode=true` at count≥3 |
| `Nomad/Components/TripRouteMapView.swift` | MKMapView UIViewRepresentable with polyline and numbered pins | VERIFIED | 192 lines; non-interactive (scroll/zoom/rotate/pitch disabled); `pointOfInterestFilter = .excludingAll`; MKPolyline amber 3pt renderer; NumberedAnnotation with UIGraphicsImageRenderer 24pt circles; lazy CLGeocoder on pin tap with `geocodeCache` and `isGeocoding` guard; `TripRouteMapContainer` at 240pt |
| `Nomad/Components/PhotoGalleryStrip.swift` | PHAsset thumbnails with GPS bbox + date-range fallback | VERIFIED | 155 lines; authorization check before fetch; two-pass matching; `resumed-flag` CheckedContinuation pattern; cap at 50; 80x80pt LazyHStack; permission-denied and empty states |
| `Nomad/Sheets/TripDetailSheet.swift` | Complete trip detail with map, stats, photos | VERIFIED | city name header (DETAIL-05); `TripRouteMapContainer` embedded (DETAIL-01); 5-cell stats row (DETAIL-02); `PhotoGalleryStrip` (DETAIL-03/04); route fetch from `FirestoreSchema.routePointsCollection` scoped to `Auth.auth().currentUser?.uid` |

---

## Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `TripDocument.swift` | `FirestoreSchema.swift` | `FirestoreSchema.TripFields` enum keys | VERIFIED | All field accesses in snapshot initializer use `FirestoreSchema.TripFields.*` constants (cityName, startDate, endDate, routePreview, stepCount, distanceMeters, visitedCountryCodes, placeCounts) |
| `GlobeViewModel.swift` | `FirestoreSchema.swift` | `tripsCollection` + userDoc fetch | VERIFIED | `TripService.fetchTrips` calls `FirestoreSchema.tripsCollection(userId)` (line 96 of TripService.swift); `fetchVisitedCountryCodes` calls `FirestoreSchema.userDoc(userId)` |
| `GlobeView.swift` | `GlobeViewModel.swift` | `viewModel.visitedCountryCodes` for overlays | VERIFIED | `addCountryOverlays(to:countries:visitedCodes:)` receives `Set(viewModel.visitedCountryCodes)` from `updateUIView`; `handleTap` reads `Set(viewModel.visitedCountryCodes)` |
| `DragStrip.swift` | `GlobeView.swift` | ZStack layer at bottom | VERIFIED | `DragStrip(onTap: { viewModel.showProfileSheet = true })` inside `VStack { Spacer(); DragStrip }` in GlobeView ZStack |
| `ProfileSheet.swift` | `TripDocument.swift` | `trips: [TripDocument]` parameter | VERIFIED | ProfileSheet accepts `[TripDocument]`, `TripPreviewCard` consumes `TripDocument` fields directly |
| `RoutePreviewPath.swift` | `ProfileSheet.swift` | `RoutePreviewPath` in trip cards | VERIFIED | `TripPreviewCard.body` renders `RoutePreviewPath(routePreview: trip.routePreview, size: geo.size)` inside GeometryReader |
| `RecordingPill.swift` | `LocationManager.swift` | reads `isRecording`, calls `stopRecording` | VERIFIED | `@Environment(LocationManager.self)` in RecordingPill; `GlobeView`: `locationManager.startRecording(tripId:)` in onStartTrip, `locationManager.stopRecording()` in `saveTrip`/`discardTrip` |
| `GlobeView.swift` | `RecordingPill.swift` | conditional ZStack layer when isRecording | VERIFIED | `if locationManager.isRecording { RecordingPill(...) }` — conditional presence (not opacity), timer cancels on false |
| `AppDelegate.swift` | `VisitMonitor.swift` | UserDefaults `manualOnlyMode` flag | VERIFIED | AppDelegate sets `manualOnlyMode=true` in UserDefaults; VisitMonitor reads it via `UserDefaults.standard.bool(forKey: "manualOnlyMode")` |
| `TripRouteMapView.swift` | `FirestoreSchema.swift` | `routePointsCollection` fetch for GPS trace | VERIFIED | `TripDetailSheet.fetchRoutePoints()` calls `FirestoreSchema.routePointsCollection(uid, tripId: trip.id)` and passes coordinates to `TripRouteMapContainer` |
| `PhotoGalleryStrip.swift` | Photos framework | `PHImageManager.default().requestImage` | VERIFIED | `PHImageManager.default()` used at line 124; `manager.requestImage(for:targetSize:contentMode:options:)` with resumed-flag continuation |
| `TripDetailSheet.swift` | `TripRouteMapView.swift` | embedded at 240pt height | VERIFIED | `TripRouteMapContainer(routeCoordinates:places:isLoading:)` at line 57 of TripDetailSheet |

---

## Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| `ProfileSheet` trip list | `trips: [TripDocument]` | `GlobeViewModel.loadGlobeData()` → `TripService.fetchTrips` → Firestore | Yes — Firestore query `tripsCollection(uid).order(by:startDate, descending:true).getDocuments()` | FLOWING |
| `GlobeView` country overlays | `viewModel.visitedCountryCodes` | `TripService.fetchVisitedCountryCodes` → Firestore user doc | Yes — `userDoc(uid).getDocument()` reads `visitedCountryCodes` field | FLOWING |
| `TripDetailSheet` route map | `routeCoordinates` | `fetchRoutePoints()` → `FirestoreSchema.routePointsCollection` | Yes — Firestore subcollection ordered by timestamp | FLOWING |
| `PhotoGalleryStrip` thumbnails | `thumbnails` | `PHAsset.fetchAssets` + `PHImageManager.requestImage` | Yes — real PHAssets from Photos library matching date/bbox | FLOWING |
| `RecordingPill` elapsed timer | `elapsedSeconds` | `Timer.publish(every: 1)` + `.onReceive` | Yes — real clock increments | FLOWING |
| `GlobeView` trip pinpoints | `viewModel.trips` | `TripService.fetchTrips` → Firestore | Yes — same Firestore fetch as ProfileSheet list | FLOWING |

---

## Behavioral Spot-Checks

Step 7b: SKIPPED — No runnable entry points available without a physical device (app requires iOS Simulator or device with Firebase backend; spot-checks would require a running app instance).

---

## Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| PANEL-01 | 03-02 | Bottom sheet accessible via persistent handle | VERIFIED | DragStrip at bottom of GlobeView ZStack, always visible |
| PANEL-02 | 03-01, 03-02 | Trips listed chronologically as route preview cards | VERIFIED | ProfileSheet LazyVStack with TripPreviewCard + RoutePreviewPath; ordered by startDate desc |
| PANEL-03 | 03-02 | Tap trip card → full trip detail panel | VERIFIED | `.onTapGesture` → `detailTrip = trip; showTripDetail = true`; nested .sheet |
| PANEL-04 | 03-02 | TripDetailSheet dismissed by sliding down, ProfileSheet stays | VERIFIED | INFRA-02 nested sheet pattern: TripDetailSheet's .sheet is inside ProfileSheet body |
| PANEL-05 | 03-02, 03-03 | "+" button opens new trip log flow | VERIFIED | `plus.circle.fill` button calls `onStartTrip?()`; closure wired in GlobeView to generate UUID + startRecording |
| PANEL-06 | 03-02 | Profile button opens Traveler Passport | VERIFIED | `person.circle` button → `TravelerPassportStub` |
| TRIP-01 | 03-03 | Manual trip start from "+" button | VERIFIED | `onStartTrip` closure: UUID + `locationManager.startRecording(tripId:)` |
| TRIP-02 | 03-03 | Notification prompt on CLVisit departure | VERIFIED | `VisitMonitor.handleGeofenceExit()` → `sendTripStartNotification()` |
| TRIP-03 | 03-03 | 3 dismissed prompts → manual-only mode | VERIFIED | AppDelegate dismiss counter + `manualOnlyMode` UserDefaults flag |
| TRIP-04 | 03-03 | Active trip indicator on globe | VERIFIED | RecordingPill conditional ZStack layer |
| TRIP-05 | 03-03 | GPS trace + places + steps + date + city captured | VERIFIED | `saveTrip` → `fetchUnsyncedPoints` + `queryStepCount(HKStatisticsQuery)` + `calculateDistance` + `TripService.finalizeTrip` |
| TRIP-06 | 03-03 | User can stop and name trip | VERIFIED | UIAlertController with text field; Save disabled until non-empty |
| TRIP-07 | 03-03 | Trip stored with GPS subcollection + 50pt preview | VERIFIED | `TripService.finalizeTrip` calls `RouteSimplifier` then writes routePreview + syncRoutePoints batched subcollection |
| DETAIL-01 | 03-04 | Map shows GPS trace polyline + named place pins | VERIFIED | TripRouteMapView: MKPolyline amber renderer + NumberedAnnotation amber circles |
| DETAIL-02 | 03-04 | Trip stats: steps, distance, duration, places, top category | VERIFIED | 5-cell HStack statsRow in TripDetailSheet |
| DETAIL-03 | 03-04 | Photo gallery — PHAssets matched by date + bbox | VERIFIED | PhotoGalleryStrip two-pass matching |
| DETAIL-04 | 03-04 | Nil-location photos via date-range fallback | VERIFIED | `else { matchedAssets.append(asset) }` branch in PhotoGalleryStrip |
| DETAIL-05 | 03-04 | City name as trip header | VERIFIED | `Text(trip.cityName).font(AppFont.title())` at top of TripDetailSheet |

**All 19 Phase 3 requirements: VERIFIED by code structure**

---

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `TravelerPassportStub.swift` | 17 | "Passport coming soon." | Info | Intentional — PANEL-06 explicitly permits stub; full implementation is Phase 4 scope |
| `GlobeView.swift` | 268 | `onStartTrip: nil` removed in 03-02, then re-added in 03-03 | Info (resolved) | Was temporary; 03-03 wired the closure; current code has the live closure |

No blockers or warnings found. The only stub (`TravelerPassportStub`) is explicitly planned and deferred to Phase 4.

---

## Deferred Items

| Item | Addressed In | Evidence |
|------|-------------|----------|
| Traveler Passport full implementation | Phase 4 | Phase 4 goal: "Build the identity layer... Traveler Passport view with a flat world map and lifetime stats" |

---

## Human Verification Required

### 1. Profile panel with live Firestore data

**Test:** Log into the app on device or simulator with a Firestore backend. Tap the DragStrip.
**Expected:** ProfileSheet slides up listing real trips (or "No trips yet." empty state). Trip cards show route path, city name, date, distance/steps.
**Why human:** Live Firestore reads require authenticated session and network.

### 2. Recording pill real-time behavior

**Test:** Tap "+" in ProfileSheet. Observe globe home view.
**Expected:** ProfileSheet dismisses, RecordingPill appears at top with pulsing red dot and elapsed timer incrementing every second. "Stop Trip" button visible.
**Why human:** Timer animation and conditional ZStack insertion require the app to be running.

### 3. Trip save end-to-end flow

**Test:** With RecordingPill active (walk around for 30+ seconds), tap "Stop Trip", enter "Test Trip", tap "Save Trip".
**Expected:** Alert dismisses, pill disappears, globe refreshes with new pinpoint. Country highlighting updates if a new country was visited.
**Why human:** Requires real GPS points, HealthKit authorization, Firestore write, and globe re-render chain.

### 4. TripDetailSheet nested dismissal (INFRA-02)

**Test:** Tap a trip card in ProfileSheet. Then slide down TripDetailSheet.
**Expected:** TripDetailSheet slides away; ProfileSheet remains visible beneath. No cascade.
**Why human:** SwiftUI sheet cascade behavior must be verified on device.

### 5. MapKit route rendering in TripDetailSheet

**Test:** Open TripDetailSheet for a trip with recorded route points.
**Expected:** 240pt MapKit map renders amber polyline; numbered amber circle pins appear in visit order; tapping a pin shows reverse-geocoded place name in callout.
**Why human:** Requires Firestore routePoints data and live MapKit.

### 6. Auto-detect dismiss counter (TRIP-03)

**Test:** Force 3 geofence exit notifications and swipe each one away.
**Expected:** After 3rd swipe, UserDefaults `manualOnlyMode` is true; no further notifications fire on subsequent geofence exits.
**Why human:** CLRegion monitoring requires physical device, location simulation, and notification interaction.

---

## Gaps Summary

No implementation gaps found. All 7 roadmap success criteria are backed by substantive, wired, and data-flowing code. All 19 Phase 3 requirements (PANEL-01 through DETAIL-05) are implemented. All 15 required artifacts exist with correct content. All 13 key links are verified. The only "stub" is TravelerPassportStub, which is explicitly permitted by the roadmap and PANEL-06 requirement ("stub view acceptable in this phase").

The `human_needed` status reflects 6 behavioral items that require the app to be running with a live backend — not code deficiencies.

---

_Verified: 2026-04-06_
_Verifier: Claude (gsd-verifier)_
