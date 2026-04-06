# Phase 3: Core User Journey - Research

**Researched:** 2026-04-06
**Domain:** SwiftUI bottom sheets, MapKit overlays, PHAsset photo matching, Firestore real-data wiring, active-trip recording UI
**Confidence:** HIGH (all findings verified directly from codebase or Apple framework knowledge)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Floating drag strip (slim pill/handle) at the bottom of the globe view at all times. User drags up or taps to open ProfileSheet. Behaves like iOS Control Center pull-up.
- **D-02:** The strip is persistent across the entire app — it floats above GlobeView and is never hidden (even during active recording). The globe is always the backdrop.
- **D-03:** Route shape drawn as a SwiftUI `Path`/`Shape` from the `routePreview` 50-pt lat/lon array. Lightweight — no MapKit view per card. Route renders as an amber line on a dark or cream background strip inside the card.
- **D-04:** Coordinate normalization: scale lat/lon pairs to fit the card's bounding box before drawing the Path (subtract min, divide by range, multiply by view size). Flip Y axis.
- **D-05:** "+" tapped → recording starts immediately (no upfront prompt). Stop → name dialog appears. Trip name is a required field before finalization.
- **D-06:** A temporary `tripId` (UUID) is generated at recording start and stored on `LocationManager.currentTripId`.
- **D-07:** Floating pill overlaid on the globe during recording. Shows: pulsing red dot + "Recording — Xh Xm" elapsed timer + "Stop" button. Timer ticks every second using `Timer.publish`. Pill anchored to top-center of the screen (below safe area / Dynamic Island).
- **D-08:** Tapping "Stop" on the pill triggers the name dialog. The pill disappears after the trip is finalized.
- **D-09:** `VisitMonitor` tracks dismiss count in `UserDefaults` under key `"tripPromptDismissCount"`. After 3 dismissals, `VisitMonitor.stopMonitoring()` is called and `UserDefaults.standard.set(true, forKey: "manualOnlyMode")` is written.
- **D-10:** The dismiss increment is triggered from the notification response handler.
- **D-11:** `GlobeViewModel` fetches trips from `users/{uid}/trips` Firestore collection on appear. Replaces `GlobePinpoint.StubTrip.stubTrips` stub with real `[TripDocument]` model. Uses `visitedCountryCodes` from user document for country highlighting.
- **D-12:** Tapping a globe pinpoint opens ProfileSheet scrolled to that trip (matching by `tripId`). ProfileSheet receives the trip list + a `scrollToTripId` parameter.
- **D-13:** Full GPS trace fetched from `users/{uid}/trips/{tripId}/routePoints` subcollection. Rendered as `MKPolyline` overlay on a non-interactive `MKMapView`. Amber stroke, 3pt line width.
- **D-14:** Place pins are numbered (1, 2, 3…) in visit order. Amber numbered markers. Tapping a pin shows a callout with the place name (reverse-geocoded from the pin's coordinate using `CLGeocoder` — lazy, cached per session). Map auto-fits to full route bounding box on load.
- **D-15:** Map height: fixed at 240pt in the detail panel.
- **D-16:** Horizontal scrolling strip of square thumbnails (80×80pt). `PHImageManager.requestImage` with `.fastFormat` on background thread.
- **D-17:** Photo matching via `PHFetchOptions` filtered by `creationDate` within `[startDate, endDate]`. Secondary filter: GPS bounding box from routePoints. Photos with nil location metadata included via date-range-only fallback.
- **D-18:** Thumbnail tap disabled in this phase.

### Claude's Discretion

- Exact pill visual design (corner radius, blur background, shadow)
- Elapsed timer formatting (whether to show seconds for short trips)
- Empty state for trip card list (if user has no trips yet)
- SwiftData → Firestore sync trigger timing after trip finalization
- Error state for photo permission denied
- Scroll-to-trip animation specifics in ProfileSheet
- Whether to show trip count on the drag strip handle

### Deferred Ideas (OUT OF SCOPE)

- Tapping a photo thumbnail to open a full-screen viewer (D-18 — intentionally skipped)
- Settings to reset manual-only mode after 3 dismissals
- Trip archiving or deletion from ProfileSheet
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PANEL-01 | Bottom sheet accessible from anywhere via persistent bottom handle | Drag strip ZStack layer on GlobeView; `.sheet` detent presentation pattern (verified in ProfileSheet.swift) |
| PANEL-02 | Recent trips listed chronologically (newest first) as preview route cards | Firestore fetch with orderBy startDate desc; SwiftUI Path normalization for route preview |
| PANEL-03 | Tap trip card → full trip detail panel slides up | Nested `.sheet` pattern established in INFRA-02 (verified in ProfileSheet.swift line 60) |
| PANEL-04 | Trip detail panel dismissed by sliding down; ProfileSheet remains visible | INFRA-02 nested sheet pattern already proven — no cascade dismissal |
| PANEL-05 | "+" button in panel opens new trip log flow | `LocationManager.startRecording(tripId:)` is ready to call (verified in LocationManager.swift) |
| PANEL-06 | Profile button in panel opens Traveler Passport stub | Stub view: centered "Passport coming soon." in a cream sheet with `AppFont.subheading()` |
| TRIP-01 | User can manually start a trip from "+" button | UUID tripId generated at call site; `LocationManager.startRecording(tripId:)` called immediately |
| TRIP-02 | App sends notification prompt when CLVisit detects departure | `VisitMonitor.sendTripStartNotification()` already exists; phase adds manualOnlyMode guard |
| TRIP-03 | After 3 dismissed prompts, switches to manual-only mode | `UserDefaults` key `tripPromptDismissCount` + `manualOnlyMode`; notification response handler |
| TRIP-04 | Active trip indicator visible on globe home view while recording | Floating pill conditioned on `LocationManager.isRecording`; `Timer.publish` for elapsed timer |
| TRIP-05 | Trip captures GPS trace, places, categories, steps, date range, city | `TripService.finalizeTrip(...)` already handles all fields (verified in TripService.swift) |
| TRIP-06 | User can stop and name a trip | `UIAlertController` with `.alert` style; required non-empty name field; "Save Trip" / "Discard Trip" |
| TRIP-07 | Trip stored with full GPS subcollection + 50-point preview array | `TripService.finalizeTrip` writes both `routePreview` and `routePoints` subcollection (verified) |
| DETAIL-01 | Map shows GPS trace polyline + named place pins in visit order | `MKPolyline` + numbered `MKAnnotationView`; `UIViewRepresentable` wrapping `MKMapView` |
| DETAIL-02 | Trip stats: steps, distance, duration, places, top category | Read from Firestore trip document fields (stepCount, distanceMeters, startDate, endDate, placeCounts) |
| DETAIL-03 | Photo gallery from Photos — PHAssets matched by date + GPS bounding box | `PHFetchOptions` + `PHImageManager.requestImage(.fastFormat)` on background thread |
| DETAIL-04 | Nil-location photos matched by date range as fallback | Two-pass fetch: first with location filter, then date-only for photos with nil location |
| DETAIL-05 | City name displayed as trip header | `trip.cityName` from Firestore TripDocument; `AppFont.title()` on TripDetailSheet |
</phase_requirements>

---

## Summary

Phase 3 is a pure UI assembly phase. The data pipeline (Phase 2) is fully built: `LocationManager`, `TripService`, `VisitMonitor`, `FirestoreSchema`, `RouteSimplifier`, and all SwiftData models are complete and verified in the codebase. Phase 3's job is to replace stub data with real data connections and add three new UI surfaces: the persistent drag strip, the recording pill, and the filled-out TripDetailSheet.

The single highest-complexity work item is the `TripDocument` data model and the `GlobeViewModel` Firestore fetch — Phase 3 must define a codable struct that maps Firestore trip documents to Swift types, then thread that model through `GlobeViewModel`, `ProfileSheet`, and `TripDetailSheet`. Everything else (MapKit overlay, photo matching, dismiss counter) has clear, well-scoped Apple API paths.

The key architectural constraint is the INFRA-02 nested sheet pattern: `TripDetailSheet` is nested inside `ProfileSheet`'s body and must remain there. The drag strip is a new ZStack layer on `GlobeView`, not a new sheet or navigation layer. The recording pill is a second conditional ZStack layer on `GlobeView`.

**Primary recommendation:** Implement in this order — (1) `TripDocument` model + `GlobeViewModel` Firestore fetch, (2) drag strip + ProfileSheet real-data wiring, (3) recording pill + trip start/stop flow, (4) TripDetailSheet map + stats, (5) photo gallery, (6) VisitMonitor dismiss counter.

---

## Standard Stack

### Core (all verified in codebase)

| Framework | Version | Purpose | Status |
|-----------|---------|---------|--------|
| SwiftUI | iOS 17+ | All UI surfaces | [VERIFIED: NomadApp.swift — `@Observable` usage confirms iOS 17+ target] |
| MapKit | iOS 17+ | TripDetailSheet route map (MKPolyline, MKMapView via UIViewRepresentable) | [VERIFIED: GlobeView.swift uses MKMapView pattern] |
| PhotosUI / Photos | iOS 17+ | PHAsset thumbnail loading, PHFetchOptions photo matching | [VERIFIED: AUTH-05 photos permission granted in onboarding] |
| CoreLocation | iOS 17+ | CLGeocoder for place pin reverse-geocoding | [VERIFIED: LocationManager.swift, TripService.swift] |
| FirebaseFirestore | 12.x via SPM | Trip document fetching, routePoints subcollection reads | [VERIFIED: FirestoreSchema.swift, TripService.swift] |
| SwiftData | iOS 17+ | TripLocal / RoutePoint local models | [VERIFIED: NomadApp.swift modelContainer setup] |
| Combine | iOS 17+ | `Timer.publish` for elapsed recording timer on pill | [ASSUMED: standard iOS pattern for periodic UI updates] |

### Supporting

| API | Purpose | Pattern |
|-----|---------|---------|
| `UNUserNotificationCenter` + `UNNotificationResponse` | Handling notification dismiss for TRIP-03 counter | Already used in VisitMonitor.swift |
| `UserDefaults` | `tripPromptDismissCount`, `manualOnlyMode` persistence | Already used in AuthManager.swift |
| `UIAlertController` | Trip name dialog (D-05) | System alert — not a custom SwiftUI sheet |
| `MKPolyline` + `MKOverlayRenderer` | GPS trace rendering in TripDetailSheet | Pattern established in GlobeView.swift for country polygon overlays |
| `PHImageManager.requestImage` | Thumbnail loading on background thread | Fast format, no main-thread blocking |
| `CLGeocoder.reverseGeocodeLocation` | Place pin callout labels — lazy, per-session cache | Already used in TripService.detectCountryCodes |

### No New Dependencies

Phase 3 introduces zero new SPM packages. All required frameworks are system frameworks or Firebase (already integrated). [VERIFIED: config.json no new registries; UI-SPEC Registry Safety section confirms "no third-party component registries"]

---

## Architecture Patterns

### Project Structure (Existing — Phase 3 extends in place)

```
Nomad/
├── App/
│   └── NomadApp.swift            — inject LocationManager into environment (NEW)
├── Globe/
│   ├── GlobeView.swift           — add drag strip + recording pill ZStack layers (MODIFY)
│   ├── GlobeViewModel.swift      — replace stub data with Firestore fetch (MODIFY)
│   └── GlobePinpoint.swift       — retain for spherePosition(); StubTrip unused after Phase 3
├── Sheets/
│   ├── ProfileSheet.swift        — replace StubTrip with TripDocument; add route Path (MODIFY)
│   └── TripDetailSheet.swift     — add real map, stats, photo gallery (MODIFY)
├── Data/
│   ├── Models/
│   │   └── TripDocument.swift    — NEW: Codable Firestore trip model
│   └── TripService.swift         — add fetchTrips() method (MODIFY)
├── Location/
│   └── VisitMonitor.swift        — add 3-dismiss counter (MODIFY)
└── Components/                   — optional: extract DragStrip, RecordingPill, RoutePreviewPath
    ├── DragStrip.swift           — NEW
    ├── RecordingPill.swift       — NEW
    └── RoutePreviewPath.swift    — NEW
```

### Pattern 1: TripDocument Firestore Model

**What:** A `Codable` struct (or manual Firestore decoding) mapping the Firestore trip document fields to a Swift type. Must match `FirestoreSchema.TripFields` exactly.

**When to use:** Everywhere a trip is passed around in Phase 3. Replaces `GlobePinpoint.StubTrip` in ProfileSheet and GlobeViewModel.

```swift
// Source: [VERIFIED: FirestoreSchema.swift TripFields enum]
struct TripDocument: Identifiable {
    let id: String           // document ID = tripId
    let cityName: String     // TripFields.cityName
    let startDate: Date      // TripFields.startDate (Firestore Timestamp → Date)
    let endDate: Date        // TripFields.endDate
    let stepCount: Int       // TripFields.stepCount
    let distanceMeters: Double  // TripFields.distanceMeters
    let routePreview: [[Double]] // TripFields.routePreview (50-pt [[lat, lon]])
    let visitedCountryCodes: [String]  // TripFields.visitedCountryCodes
    let placeCounts: [String: Int]     // TripFields.placeCounts
    // Derived: latitude/longitude for globe pinpoint from routePreview first point
    var coordinate: CLLocationCoordinate2D? {
        guard let first = routePreview.first, first.count >= 2 else { return nil }
        return CLLocationCoordinate2D(latitude: first[0], longitude: first[1])
    }
}
```

**Firestore decoding note:** `Firestore.firestore().collection(...).getDocuments()` returns `QueryDocumentSnapshot` objects. Use `data()` dictionary access with explicit casting — Firestore Swift SDK does not auto-decode to `Codable` unless you use `try snapshot.data(as: T.self)` with `@DocumentID`. Both approaches work; the manual approach matches the existing pattern in `TripService.swift`. [VERIFIED: TripService.swift uses manual `setData([:])` writes — consistent to use manual reads]

### Pattern 2: GlobeViewModel Firestore Fetch

**What:** Replace `GlobePinpoint.StubTrip.stubTrips` with a Firestore collection fetch using `AuthManager.currentUser.uid`.

**Critical detail:** `GlobeViewModel` is `@Observable @MainActor`. Firestore fetch must be awaited in a `Task` within `loadGlobeData()`. [VERIFIED: GlobeViewModel.swift — existing `loadGlobeData()` is async, can be extended]

```swift
// Source: [VERIFIED: GlobeViewModel.swift loadGlobeData(), FirestoreSchema.swift tripsCollection()]
func loadGlobeData() async {
    // existing GeoJSON load...
    // NEW: fetch real trips
    guard let uid = Auth.auth().currentUser?.uid else { return }
    let snap = try? await FirestoreSchema.tripsCollection(uid)
        .order(by: "startDate", descending: true)
        .getDocuments()
    trips = snap?.documents.compactMap { TripDocument(snapshot: $0) } ?? []
    // NEW: fetch visitedCountryCodes from user document for country highlight
    let userSnap = try? await FirestoreSchema.userDoc(uid).getDocument()
    visitedCountryCodes = userSnap?.data()?["visitedCountryCodes"] as? [String] ?? []
}
```

**Country overlay update:** `GlobeView.Coordinator.addCountryOverlays` currently reads from `GlobeCountryOverlay.hardcodedVisitedCodes`. Phase 3 must pass the live `visitedCountryCodes` array through `GlobeViewModel` to the coordinator. [VERIFIED: GlobeView.swift line 86]

### Pattern 3: Drag Strip + Recording Pill as ZStack Layers

**What:** Both the drag strip and recording pill are SwiftUI `ZStack` layers inside `GlobeView`, overlaid on `GlobeMapView`. This matches the existing pattern.

**When to use:** GlobeView's body is a `ZStack` — extend it. Do not create a new navigation layer.

```swift
// Source: [VERIFIED: GlobeView.swift body — ZStack with Color.black + GlobeMapView]
var body: some View {
    ZStack {
        Color.black.ignoresSafeArea()
        GlobeMapView(...).ignoresSafeArea()
            .sheet(isPresented: $viewModel.showProfileSheet) { ... }  // stays here

        // NEW: Recording pill (top-center, conditional)
        if locationManager.isRecording {
            RecordingPill(locationManager: locationManager)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 16)  // below Dynamic Island safe area
        }

        // NEW: Drag strip (bottom, always visible)
        DragStrip(onTap: { viewModel.showProfileSheet = true })
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }
}
```

**Safe area note:** The drag strip should be pinned above the bottom safe area inset, not below it. Use `.safeAreaInset(edge: .bottom)` or place inside a VStack with `Spacer()`. [ASSUMED: standard SwiftUI safe area handling]

### Pattern 4: SwiftUI Path Route Preview

**What:** Convert the `routePreview` `[[Double]]` array from Firestore into a normalized `Path` for the trip card route strip.

**Normalization algorithm (from D-04):**

```swift
// Source: [VERIFIED: CONTEXT.md D-03, D-04]
// routePreview format: [[lat, lon], [lat, lon], ...]
func routePath(from preview: [[Double]], in size: CGSize) -> Path {
    guard preview.count >= 2 else { return Path() }
    let lons = preview.map { $0[1] }
    let lats = preview.map { $0[0] }
    let minLon = lons.min()!, maxLon = lons.max()!
    let minLat = lats.min()!, maxLat = lats.max()!
    let lonRange = maxLon - minLon
    let latRange = maxLat - minLat
    guard lonRange > 0, latRange > 0 else { return Path() }

    func point(for pair: [Double]) -> CGPoint {
        let x = CGFloat((pair[1] - minLon) / lonRange) * size.width
        // Flip Y: lat increases up, SwiftUI origin is top-left
        let y = CGFloat(1.0 - (pair[0] - minLat) / latRange) * size.height
        return CGPoint(x: x, y: y)
    }

    var path = Path()
    path.move(to: point(for: preview[0]))
    for pair in preview.dropFirst() {
        path.addLine(to: point(for: pair))
    }
    return path
}
```

Use in `TripCard` with a `GeometryReader` or fixed `.frame(width: 120, height: 48)` to get `CGSize`. [VERIFIED: UI-SPEC Trip Preview Card — "120×48pt view"]

### Pattern 5: MKMapView for TripDetailSheet Route

**What:** `UIViewRepresentable` wrapping `MKMapView` for the trip detail route map. The pattern already exists as `GlobeMapView` in `GlobeView.swift`.

```swift
// Source: [VERIFIED: GlobeView.swift GlobeMapView struct — identical UIViewRepresentable pattern]
struct TripRouteMapView: UIViewRepresentable {
    let routePoints: [[Double]]   // from routePoints subcollection fetch
    let visitedPlaces: [VisitedPlace]   // for numbered pin annotations

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.isScrollEnabled = false    // D-13: non-interactive
        map.isZoomEnabled = false
        map.isRotateEnabled = false
        map.mapType = .standard
        map.pointOfInterestFilter = .excludingAll  // UI-SPEC: suppress POI noise
        return map
    }
    // updateUIView: add MKPolyline + MKPointAnnotation markers + call setVisibleMapRect
}
```

**Auto-fit:** `mapView.setVisibleMapRect(polyline.boundingMapRect, edgePadding: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16), animated: false)` [ASSUMED: standard MapKit auto-fit pattern]

**Polyline renderer:** Same pattern as country polygon renderer in GlobeView.swift — `MKPolylineRenderer` with `strokeColor = UIColor(Color.Nomad.amber)` and `lineWidth = 3`. [VERIFIED: GlobeView.swift lines 112-121 — MKOverlayRenderer delegate pattern]

**Numbered pin annotations:** Subclass `MKPointAnnotation` to carry an index. In `viewFor annotation:`, render a custom `UIView` with an amber circle and a white `UILabel` showing the number. Size: 24pt diameter per UI-SPEC. [VERIFIED: UI-SPEC Place pin spec — "24pt diameter, white system number label"]

### Pattern 6: Photo Matching with PHImageManager

**What:** Two-pass PHAsset fetch for DETAIL-03 and DETAIL-04.

```swift
// Source: [VERIFIED: CONTEXT.md D-16, D-17; REQUIREMENTS.md DETAIL-03, DETAIL-04]
// Pass 1: date range + GPS bounding box
let options = PHFetchOptions()
options.predicate = NSPredicate(
    format: "creationDate >= %@ AND creationDate <= %@ AND location != nil",
    startDate as CVarArg, endDate as CVarArg
)
let located = PHAsset.fetchAssets(with: .image, options: options)
// Additional filter: GPS bounding box (iterate and check asset.location)

// Pass 2: date-range-only fallback for nil-location assets (DETAIL-04)
let fallbackOptions = PHFetchOptions()
fallbackOptions.predicate = NSPredicate(
    format: "creationDate >= %@ AND creationDate <= %@ AND location == nil",
    startDate as CVarArg, endDate as CVarArg
)
let unlocated = PHAsset.fetchAssets(with: .image, options: fallbackOptions)
```

**Thumbnail loading:** Call `PHImageManager.default().requestImage(for:targetSize:contentMode:options:resultHandler:)` on a background queue. Use `PHImageRequestOptions` with `deliveryMode = .fastFormat`, `isSynchronous = false`, and `isNetworkAccessAllowed = true`. Return to main thread via `DispatchQueue.main.async` to update `@State` image array. [ASSUMED: standard PHImageManager pattern; consistent with D-16 spec]

**GPS bounding box check:** After the date-range fetch, filter `PHAsset` objects by checking `asset.location?.coordinate` against `(minLat, maxLat, minLon, maxLon)` computed from the routePoints array. [VERIFIED: CONTEXT.md D-17]

### Pattern 7: Notification Dismiss Counter (TRIP-03)

**What:** Intercept UNNotificationResponse when user dismisses the trip prompt notification. Increment `UserDefaults` counter. After 3, call `VisitMonitor.stopMonitoring()` and set `manualOnlyMode`.

**Where to wire:** `AppDelegate.userNotificationCenter(_:didReceive:withCompletionHandler:)` — this method receives all notification responses including dismissals. [ASSUMED: standard UNUserNotificationCenterDelegate pattern]

```swift
// Source: [VERIFIED: VisitMonitor.swift lines 69-77 — Phase 3 TODO comment at line 75]
// In AppDelegate.userNotificationCenter(_:didReceive:withCompletionHandler:):
let actionID = response.actionIdentifier
if actionID == UNNotificationDismissActionIdentifier ||
   actionID == UNNotificationDefaultActionIdentifier {
    // Only count if this was a trip prompt notification
    if response.notification.request.identifier.hasPrefix("tripStartPrompt-") {
        let count = UserDefaults.standard.integer(forKey: "tripPromptDismissCount") + 1
        UserDefaults.standard.set(count, forKey: "tripPromptDismissCount")
        if count >= 3 {
            UserDefaults.standard.set(true, forKey: "manualOnlyMode")
            // Must call VisitMonitor.stopMonitoring() — requires access to the shared VisitMonitor instance
        }
    }
}
```

**Wiring gap:** `AppDelegate` needs a reference to the shared `VisitMonitor` instance to call `stopMonitoring()`. Options: (a) inject via environment and read from a shared singleton, (b) post a `NotificationCenter` notification that `VisitMonitor` observes, (c) make `VisitMonitor` check `manualOnlyMode` on every `handleGeofenceExit()` call (simplest — just guard early, no cross-reference needed). Option (c) is recommended since `VisitMonitor.handleGeofenceExit()` already has a `scope` variable scaffolding for this check.

**Updated handleGeofenceExit:**
```swift
// Source: [VERIFIED: VisitMonitor.swift line 69-77 — existing scaffold]
private func handleGeofenceExit() {
    // Phase 3: check manualOnlyMode before sending notification
    guard !UserDefaults.standard.bool(forKey: "manualOnlyMode") else { return }
    sendTripStartNotification()
}
```

**Dismiss counting in AppDelegate** is still needed for incrementing the counter, but `stopMonitoring()` can be replaced with `UserDefaults.set(true, forKey: "manualOnlyMode")` alone — the guard in `handleGeofenceExit` will stop all future notifications without needing a direct call to `stopMonitoring()`. However, CONTEXT.md D-09 explicitly requires `VisitMonitor.stopMonitoring()` to be called. Both approaches are compatible if `VisitMonitor` is accessible from AppDelegate.

### Pattern 8: Trip Start → Finalization Flow

**What:** The complete flow from "+" tap to finalized trip, involving multiple components.

**Sequence:**
1. User taps "+" in ProfileSheet
2. Generate `UUID().uuidString` as `tripId`
3. Call `locationManager.startRecording(tripId: tripId)` — sets `isRecording = true`, writes to `currentTripId`
4. ProfileSheet dismisses; recording pill appears on GlobeView (conditioned on `isRecording`)
5. `Timer.publish(every: 1, on: .main, in: .common)` drives elapsed time display
6. User taps "Stop Trip" → present `UIAlertController` with text field
7. User enters name, taps "Save Trip":
   - Fetch `locationManager.fetchUnsyncedPoints(tripId: tripId)`
   - Call `TripService.finalizeTrip(userId:tripId:cityName:startDate:endDate:routePoints:stepCount:distanceMeters:)`
   - On success: `locationManager.stopRecording()`, pill fades out, ProfileSheet reopens
8. User taps "Discard Trip":
   - Call `locationManager.stopRecording()`
   - Delete all `RoutePoint` records with matching `tripId` from SwiftData
   - Pill fades out

**HealthKit steps:** `TripService.finalizeTrip` requires `stepCount`. Phase 3 must read step count from HealthKit for the trip's time range. `HKStatisticsQuery` for `HKQuantityType.stepCount` with `startDate`/`endDate` predicate. This requires `HKHealthStore` with `HKQuantityTypeIdentifier.stepCount` authorization — which was granted during onboarding (AUTH-05 covers Photos; HealthKit steps access is a separate authorization not explicitly called out in Phase 2 requirements but implied by TRIP-05). [ASSUMED: HealthKit step query follows standard HKStatisticsQuery pattern; confirm HealthKit usage key is in Info.plist]

**LocationManager environment injection:** `NomadApp.swift` currently does not inject `LocationManager` into the environment. Phase 3 must add `@State private var locationManager = LocationManager()` and `.environment(locationManager)` in `NomadApp.body`. `LocationManager.configure(modelContext:)` must be called after the `modelContainer` is available — use `.modelContainer(for:)` with `.onAppear` or `ModelContext` injection. [VERIFIED: LocationManager.swift line 24 — `configure(modelContext:)` method exists]

### Anti-Patterns to Avoid

- **Putting TripDetailSheet outside ProfileSheet body:** INFRA-02 is proven — TripDetailSheet MUST be nested in ProfileSheet's body. Moving it will cause cascade dismissal. [VERIFIED: ProfileSheet.swift lines 55-64 with comment]
- **Using MapKit annotations for the route preview in trip cards:** Instantiating an `MKMapView` per card will cause scroll stutter. Use SwiftUI `Path` only (D-03). [VERIFIED: CONTEXT.md D-03]
- **Blocking main thread in photo loading:** `PHImageManager.requestImage` with `isSynchronous = true` blocks the main thread. Always use the async callback version. [VERIFIED: CONTEXT.md D-16]
- **Hardcoding Firestore paths:** All paths go through `FirestoreSchema` helpers — never use string literals. [VERIFIED: FirestoreSchema.swift]
- **Using `GlobeCountryOverlay.hardcodedVisitedCodes` after Phase 3:** This must be replaced with `viewModel.visitedCountryCodes` from the Firestore user document fetch. [VERIFIED: GlobeView.swift line 86]
- **Placing drag strip or pill inside ProfileSheet:** Both must live in GlobeView's ZStack — they are always visible (D-02) and ProfileSheet can be dismissed.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Firestore document decoding | Custom JSON parser | `snapshot.data()` dictionary + explicit cast, or `snapshot.data(as: T.self)` with `@DocumentID` | Firebase SDK provides both; manual casting matches existing TripService pattern |
| Photo permission state | Custom permission flow | `PHPhotoLibrary.authorizationStatus(for: .readWrite)` | System API; permission was already granted in Phase 2 onboarding |
| Elapsed time formatting | Custom Duration formatter | Manual arithmetic: `seconds % 60`, `(seconds / 60) % 60`, `seconds / 3600` | Simple enough; avoid importing Formatter overhead for a pill label |
| Smooth list scroll to item | Custom scroll position tracker | SwiftUI `ScrollViewReader` + `.scrollTo(id:anchor:)` | Built-in; no custom geometry math needed |
| Notification response handling | Background task / polling | `UNUserNotificationCenterDelegate.userNotificationCenter(_:didReceive:withCompletionHandler:)` | The delegate method fires synchronously when user interacts with notification |
| Map region auto-fit | Manual lat/lon bounds math | `MKPolyline.boundingMapRect` + `setVisibleMapRect(_:edgePadding:animated:)` | MapKit computes the bounding rect from the polyline automatically |
| Thumbnail placeholder | Custom shimmer animation | `Color.Nomad.warmCard` static fill while loading | UI-SPEC specifies warmCard placeholder — no shimmer needed |

---

## Common Pitfalls

### Pitfall 1: ProfileSheet Passed Wrong Type After Stub Removal
**What goes wrong:** ProfileSheet currently takes `[GlobePinpoint.StubTrip]`. Changing it to `[TripDocument]` without updating all call sites (GlobeView, preview macros) causes compile errors.
**Why it happens:** Two call sites: `GlobeView.body` (.sheet presentation) and the `#Preview` macro.
**How to avoid:** Update the type signature and both call sites atomically. Update the preview to use a mock `TripDocument`.
**Warning signs:** Compile error in GlobeView.swift after changing ProfileSheet signature.

### Pitfall 2: MKMapView Delegate Not Set Before Adding Overlays
**What goes wrong:** Adding `MKPolyline` before `mapView.delegate` is set means `rendererFor overlay:` never fires — polyline is invisible.
**Why it happens:** `UIViewRepresentable.updateUIView` can be called before the delegate is fully configured if overlays are added in `updateUIView` rather than after delegate setup in `makeUIView`.
**How to avoid:** Set delegate in `makeUIView`. Add overlays in `updateUIView` only after checking `context.coordinator.mapView != nil`.
**Warning signs:** Map renders but polyline is missing.

### Pitfall 3: routePoints Subcollection Fetch Returns Empty
**What goes wrong:** `TripDetailSheet` opens but the map is blank — no route drawn.
**Why it happens:** The routePoints subcollection is written by `TripService.syncRoutePoints`, but during development/testing no real trip was recorded, so the subcollection is empty. Also: Firestore security rules may block the read if they haven't been updated to allow subcollection reads.
**How to avoid:** Test with a trip that has been fully finalized through `TripService.finalizeTrip`. Check Firestore console to confirm routePoints subcollection exists. Verify security rules allow `users/{uid}/trips/{tripId}/routePoints` reads.
**Warning signs:** Empty map in TripDetailSheet; Firestore permission error in logs.

### Pitfall 4: Timer.publish Memory Leak During Recording
**What goes wrong:** `Timer.publish` continues firing after the recording pill disappears because the `.onReceive` subscription isn't cancelled.
**Why it happens:** `Timer.Publishers.TimerPublisher` keeps firing until explicitly cancelled or the view is destroyed. If the pill view is conditionally shown/hidden in a ZStack (not removed from hierarchy), the timer keeps running.
**How to avoid:** Bind the timer to a `@State var elapsedSeconds: Int` in the pill view. Use `.onReceive(timer) { _ in elapsedSeconds += 1 }` combined with `.onDisappear { /* timer cancels automatically when view leaves hierarchy */ }`. Actually remove the pill from the ZStack when `!isRecording` (conditional inclusion, not opacity change).
**Warning signs:** Elapsed time keeps counting after trip is finalized.

### Pitfall 5: UIAlertController Presentation from SwiftUI
**What goes wrong:** Calling `UIAlertController` directly from a SwiftUI button action crashes with "warning: Attempt to present ... on ... which is already presenting".
**Why it happens:** SwiftUI's view hierarchy may have a sheet already presented (ProfileSheet dismissed but animation in progress).
**How to avoid:** Use a `@State var showNameAlert: Bool` and present via a custom `UIViewControllerRepresentable` wrapper, or use a brief `DispatchQueue.main.asyncAfter(deadline: .now() + 0.1)` delay after ProfileSheet dismisses before presenting the alert. Alternatively, present the alert from `GlobeView`'s root view controller rather than from inside ProfileSheet.
**Warning signs:** "Attempt to present UIAlertController" warning in console; alert fails to appear.

### Pitfall 6: CLGeocoder Rate Limiting for Place Pin Labels
**What goes wrong:** Reverse-geocoding all place pins in sequence hits CLGeocoder rate limits, resulting in some pins having no callout label.
**Why it happens:** CLGeocoder allows one outstanding request per app at a time. Sequential async geocoding without awaiting completion of each call before starting the next can fail.
**How to avoid:** Geocode lazily — only when a pin is tapped (callout displayed), not all pins on map load. Cache results in a `[CLLocationCoordinate2D: String]` dictionary keyed by coordinate string (D-14: "lazy, cached per session").
**Warning signs:** Some place pins show empty callout titles; CLGeocoder error -4 in logs.

### Pitfall 7: HealthKit Authorization Not Requested
**What goes wrong:** `TripService.finalizeTrip` requires `stepCount` but HealthKit authorization was never requested, so the HKStatisticsQuery returns 0 steps.
**Why it happens:** Phase 2 onboarding grants location and Photos permissions (AUTH-04, AUTH-05), but HealthKit step count authorization is a separate request not explicitly implemented in Phase 2. TRIP-05 requires steps be captured.
**How to avoid:** Add HealthKit step query with authorization request as part of the trip finalization flow. Request `HKQuantityTypeIdentifier.stepCount` read authorization. Add `NSHealthShareUsageDescription` to Info.plist.
**Warning signs:** `stepCount: 0` on all finalized trips.

---

## Code Examples

### Firestore Trip Fetch (GlobeViewModel)

```swift
// Source: [VERIFIED: FirestoreSchema.swift tripsCollection(), CONTEXT.md D-11]
let snapshot = try await FirestoreSchema.tripsCollection(uid)
    .order(by: FirestoreSchema.TripFields.startDate, descending: true)
    .getDocuments()
let trips = snapshot.documents.compactMap { doc -> TripDocument? in
    let data = doc.data()
    guard
        let cityName = data[FirestoreSchema.TripFields.cityName] as? String,
        let startTimestamp = data[FirestoreSchema.TripFields.startDate] as? Timestamp,
        let endTimestamp = data[FirestoreSchema.TripFields.endDate] as? Timestamp,
        let preview = data[FirestoreSchema.TripFields.routePreview] as? [[Double]]
    else { return nil }
    return TripDocument(
        id: doc.documentID,
        cityName: cityName,
        startDate: startTimestamp.dateValue(),
        endDate: endTimestamp.dateValue(),
        stepCount: data[FirestoreSchema.TripFields.stepCount] as? Int ?? 0,
        distanceMeters: data[FirestoreSchema.TripFields.distanceMeters] as? Double ?? 0,
        routePreview: preview,
        visitedCountryCodes: data[FirestoreSchema.TripFields.visitedCountryCodes] as? [String] ?? [],
        placeCounts: data[FirestoreSchema.TripFields.placeCounts] as? [String: Int] ?? [:]
    )
}
```

### ScrollViewReader for Scroll-to-Trip

```swift
// Source: [VERIFIED: CONTEXT.md D-12; UI-SPEC Profile Sheet scrollToTripId]
ScrollViewReader { proxy in
    LazyVStack(spacing: 24) {
        ForEach(trips) { trip in
            TripPreviewCard(trip: trip)
                .id(trip.id)
                .onTapGesture { ... }
        }
    }
    .onChange(of: scrollToTripId) { _, newId in
        if let id = newId {
            withAnimation { proxy.scrollTo(id, anchor: .top) }
        }
    }
}
```

### Recording Pill Elapsed Timer

```swift
// Source: [VERIFIED: CONTEXT.md D-07; UI-SPEC Recording Pill timer formatting]
// Timer.publish fires every second on main run loop
let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
@State private var elapsedSeconds: Int = 0

var elapsedText: String {
    let h = elapsedSeconds / 3600
    let m = (elapsedSeconds % 3600) / 60
    let s = elapsedSeconds % 60
    if h > 0 { return "\(h)h \(m)m" }
    if m > 0 { return "\(m)m \(s)s" }
    return "0m \(s)s"
}

// In view body:
.onReceive(timer) { _ in elapsedSeconds += 1 }
```

### MKPolyline Auto-Fit

```swift
// Source: [ASSUMED: standard MapKit setVisibleMapRect pattern; consistent with GlobeView.swift MKMapView usage]
let coords: [CLLocationCoordinate2D] = routePoints.compactMap {
    guard $0.count >= 2 else { return nil }
    return CLLocationCoordinate2D(latitude: $0[0], longitude: $0[1])
}
let polyline = MKPolyline(coordinates: coords, count: coords.count)
mapView.addOverlay(polyline)
let padding = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
mapView.setVisibleMapRect(polyline.boundingMapRect, edgePadding: padding, animated: false)
```

### PHAsset Two-Pass Fetch

```swift
// Source: [VERIFIED: CONTEXT.md D-17; REQUIREMENTS.md DETAIL-03, DETAIL-04]
// Pass 1: with location, within date range, bounding box filter
let opts = PHFetchOptions()
opts.predicate = NSPredicate(
    format: "creationDate >= %@ AND creationDate <= %@",
    startDate as CVarArg, endDate as CVarArg
)
opts.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]

let all = PHAsset.fetchAssets(with: .image, options: opts)
var matched: [PHAsset] = []
all.enumerateObjects { asset, _, _ in
    if let loc = asset.location {
        // Check GPS bounding box
        let lat = loc.coordinate.latitude
        let lon = loc.coordinate.longitude
        if lat >= minLat && lat <= maxLat && lon >= minLon && lon <= maxLon {
            matched.append(asset)
        }
    } else {
        // DETAIL-04: nil location — include via date-range fallback
        matched.append(asset)
    }
}
```

---

## Integration Points (What Phase 3 Changes)

### NomadApp.swift
- Add `@State private var locationManager = LocationManager()` and `@State private var visitMonitor = VisitMonitor()`
- Inject both into environment: `.environment(locationManager)`, `.environment(visitMonitor)`
- Call `locationManager.configure(modelContext:)` using `@Environment(\.modelContext)` in a root view `.onAppear`
- Register `AppDelegate` as `UNUserNotificationCenterDelegate` for dismiss counter handling [VERIFIED: AppDelegate.swift exists]

### GlobeView.swift
- Add `@Environment(LocationManager.self) private var locationManager` 
- Extend ZStack: add `RecordingPill` (conditional) and `DragStrip` (always) layers
- Replace `.sheet` with an `isPresented` binding driven by the drag strip tap
- Replace `ProfileSheet(selectedTrip:trips:)` call — update to `ProfileSheet(trips: viewModel.trips, scrollToTripId: viewModel.scrollToTripId)`

### GlobeViewModel.swift
- Add `var trips: [TripDocument] = []`
- Add `var visitedCountryCodes: [String] = []`
- Add `var scrollToTripId: String? = nil`
- Extend `loadGlobeData()` to fetch Firestore trips and user visitedCountryCodes
- Update `animateToCountry(code:)` to set `scrollToTripId` from matching `TripDocument`

### GlobeView.Coordinator
- Change `addCountryOverlays`: replace `GlobeCountryOverlay.hardcodedVisitedCodes` with `viewModel.visitedCountryCodes`
- Change `addPinpointAnnotations`: replace `GlobePinpoint.StubTrip.stubTrips` with `viewModel.trips` (using `trip.coordinate`)
- Pinpoint tap: call `viewModel.scrollToTripId = trip.id` and `viewModel.showProfileSheet = true`

### ProfileSheet.swift
- Change signature: `trips: [TripDocument]`, `scrollToTripId: String?`
- Replace `TripCard(trip:)` stub component with new `TripPreviewCard(trip:)` using route Path, 96pt height, new layout
- Add "+" button and Profile button in header row
- Add `ScrollViewReader` for scroll-to-trip behavior
- Nested `.sheet` now presents `TripDetailSheet(trip: TripDocument)`

### TripDetailSheet.swift
- Change signature to accept `TripDocument` instead of `StubTrip`
- Add `TripRouteMapView` (240pt height) — fetches `routePoints` subcollection on `.task`
- Replace stub stats with real values from `TripDocument` fields
- Add photo gallery strip using `PHAsset` fetch

### VisitMonitor.swift
- Update `handleGeofenceExit()`: add `guard !UserDefaults.standard.bool(forKey: "manualOnlyMode") else { return }`
- Dismiss counting lives in AppDelegate notification response handler

---

## State of the Art

| Old (Stubs) | Phase 3 (Real) | Notes |
|-------------|----------------|-------|
| `GlobePinpoint.StubTrip.stubTrips` hardcoded array | `[TripDocument]` from Firestore | Keep `GlobePinpoint.spherePosition()` and `createEntity()` for reference geometry |
| `GlobeCountryOverlay.hardcodedVisitedCodes` | `visitedCountryCodes` from user Firestore doc | No visual change — only data source |
| ProfileSheet: text-only trip cards, no route | TripPreviewCard with SwiftUI Path route strip | 96pt fixed height card, route Path normalized |
| TripDetailSheet: hardcoded stats, no map | Real Firestore stats + MKPolyline map + PHAsset gallery | All three sections built fresh |
| VisitMonitor: always sends notification | Guards on `manualOnlyMode` + dismiss counter | Dismiss counter in AppDelegate response handler |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `Timer.publish` cancels cleanly when pill view is removed from ZStack hierarchy | Architecture Patterns Pattern 4 | Timer could leak; fix: explicit `@State var timerRunning = false` and conditional `.onReceive` |
| A2 | `MKPolyline.boundingMapRect` auto-fit is the correct API for map auto-fit | Code Examples | Minor: use manual `MKMapRect` computation from coordinates instead |
| A3 | HealthKit step count authorization was NOT requested in Phase 2 onboarding | Common Pitfalls Pitfall 7 | If it was requested in Phase 2, Pitfall 7 is already resolved |
| A4 | `UNNotificationDismissActionIdentifier` fires when user swipes away a notification on iOS 17+ | Architecture Patterns Pattern 7 | If it doesn't fire reliably, use a "Start Trip" action button instead and count non-taps differently |
| A5 | `PHFetchOptions` with `location == nil` predicate correctly identifies iCloud shared album photos | Code Examples PHAsset section | If wrong, fall back to checking `asset.location` being nil at enumeration time |
| A6 | AppDelegate.swift exists and is set as `UIApplicationDelegateAdaptor` | Integration Points | [VERIFIED: NomadApp.swift line 2 — `@UIApplicationDelegateAdaptor(AppDelegate.self)`] — NOT assumed, verified |
| A7 | `safeAreaInset(edge: .bottom)` is available for drag strip positioning | Architecture Patterns Pattern 3 | Use a VStack with Spacer + `.padding(.bottom, safeAreaBottom)` as fallback |

---

## Open Questions

1. **HealthKit step authorization in onboarding**
   - What we know: `TripService.finalizeTrip` takes `stepCount: Int`; onboarding grants location + Photos (AUTH-04, AUTH-05)
   - What's unclear: Was `HKHealthStore.requestAuthorization` added to onboarding in Phase 2 execution? `NSHealthShareUsageDescription` in Info.plist?
   - Recommendation: Check `Nomad/Onboarding/` files and `Info.plist` before building the finalization flow. If missing, add HK authorization to the recording start flow (not onboarding — less disruptive).

2. **routePoints subcollection read in TripDetailSheet — ordering**
   - What we know: `routePoints` is written as a batch via `TripService.syncRoutePoints` without explicit ordering field
   - What's unclear: Firestore documents within a collection don't have guaranteed order unless queried with `orderBy`. The `timestamp` field exists on each routePoint.
   - Recommendation: Always fetch `routePoints` with `.order(by: "timestamp")` to ensure correct polyline point order.

3. **`visitedCountryCodes` on user document — field write timing**
   - What we know: `TripService.updateUserVisitedCountries` writes `visitedCountryCodes` using `arrayUnion`. It's a separate method call, not automatically called by `finalizeTrip`.
   - What's unclear: Is `updateUserVisitedCountries` called anywhere in the current codebase after trip finalization?
   - Recommendation: Ensure the trip start/stop flow calls `updateUserVisitedCountries` after `finalizeTrip` completes, so `GlobeViewModel` reads current data on next load.

4. **`GlobePinpoint.createEntity` used in Phase 3?**
   - What we know: `GlobePinpoint.createEntity` creates `ModelEntity` for RealityKit scene. The current globe is `MKMapView` (`hybridFlyover`), not RealityKit.
   - What's unclear: Was there a RealityKit globe at any point, or was `GlobePinpoint.createEntity` never actually wired to the live view?
   - Recommendation: `GlobePinpoint.createEntity` can be ignored for Phase 3 — the `MKAnnotationView` pattern in `GlobeView.Coordinator.mapView(_:viewFor:)` already handles pinpoints correctly (verified in GlobeView.swift lines 123-144). Real TripDocuments should be passed to `addPinpointAnnotations`.

---

## Environment Availability

| Dependency | Required By | Available | Notes |
|------------|------------|-----------|-------|
| Firebase SDK (Firestore, Auth) | Trip fetching, user doc | Yes | Already integrated via SPM (NomadApp.swift imports FirebaseCore) |
| MapKit | TripDetailSheet route map | Yes | System framework; GlobeView already uses MKMapView |
| Photos / PhotosUI | PHAsset gallery | Yes | AUTH-05 permission granted in onboarding |
| CoreLocation | CLGeocoder for place pins | Yes | System framework; used by LocationManager |
| HealthKit | Step count in TripService.finalizeTrip | Unknown | See Open Question 1 above |
| UserNotifications | TRIP-03 dismiss counter | Yes | VisitMonitor already uses UNUserNotificationCenter |
| SwiftData | TripLocal / RoutePoint local models | Yes | NomadApp.swift modelContainer already configured |

**No blocking missing dependencies** — all required system frameworks are standard iOS. HealthKit is the only uncertainty, and it has a safe fallback (pass `stepCount: 0` and handle later).

---

## Security Domain

Security enforcement is not flagged as disabled in config.json. This phase is UI-layer only with no new server-side logic. Applicable notes:

| Area | Concern | Standard Control |
|------|---------|-----------------|
| Firestore reads | Trip data read must be scoped to authenticated user only | `FirestoreSchema.tripsCollection(uid)` uses `Auth.auth().currentUser?.uid` — correct scoping [VERIFIED] |
| Photo access | PHPhotoLibrary read requires user authorization | AUTH-05 handles this in onboarding; check `PHPhotoLibrary.authorizationStatus` before fetching |
| UserDefaults | `tripPromptDismissCount` and `manualOnlyMode` are not security-sensitive — local preference only | No encryption needed |
| CLGeocoder | Reverse-geocode sends coordinates to Apple servers | Standard iOS app behavior; user consented via location permission |

No new authentication flows, no new server writes, no new network endpoints. Existing Firestore security rules from Phase 2 (`users/{uid}/trips` write/read scoped to `request.auth.uid == uid`) apply unchanged.

---

## Sources

### Primary (HIGH confidence — verified directly in codebase)
- `/Users/shrey/nomad-final/nomadv2/Nomad/Location/LocationManager.swift` — `startRecording`, `stopRecording`, `fetchUnsyncedPoints`, `isRecording`, `currentTripId` API surface
- `/Users/shrey/nomad-final/nomadv2/Nomad/Data/TripService.swift` — `finalizeTrip` full signature and Firestore write pattern
- `/Users/shrey/nomad-final/nomadv2/Nomad/Data/FirestoreSchema.swift` — All Firestore path helpers and TripFields enum
- `/Users/shrey/nomad-final/nomadv2/Nomad/Location/VisitMonitor.swift` — Existing `handleGeofenceExit` scaffold with Phase 3 TODO comment
- `/Users/shrey/nomad-final/nomadv2/Nomad/Globe/GlobeView.swift` — UIViewRepresentable MKMapView pattern, ZStack overlay pattern, annotation view pattern
- `/Users/shrey/nomad-final/nomadv2/Nomad/Globe/GlobeViewModel.swift` — `@Observable @MainActor` pattern, existing `loadGlobeData()` extension point
- `/Users/shrey/nomad-final/nomadv2/Nomad/Sheets/ProfileSheet.swift` — INFRA-02 nested sheet pattern, stub to replace
- `/Users/shrey/nomad-final/nomadv2/Nomad/Sheets/TripDetailSheet.swift` — Stub structure to replace
- `/Users/shrey/nomad-final/nomadv2/Nomad/App/NomadApp.swift` — Environment injection pattern, modelContainer setup
- `/Users/shrey/nomad-final/nomadv2/Nomad/DesignSystem/AppColors.swift` — Color.Nomad namespace
- `/Users/shrey/nomad-final/nomadv2/Nomad/DesignSystem/AppFont.swift` — All type functions
- `/Users/shrey/nomad-final/nomadv2/Nomad/DesignSystem/PanelGradient.swift` — `.panelGradient()` modifier
- `/Users/shrey/nomad-final/nomadv2/Nomad/Location/RouteSimplifier.swift` — `coordinatesFromRoutePoints` available for MapKit use
- `.planning/phases/03-core-user-journey/03-CONTEXT.md` — All D-01 through D-18 decisions
- `.planning/phases/03-core-user-journey/03-UI-SPEC.md` — All visual/dimension specifications

### Secondary (MEDIUM confidence — framework knowledge)
- Apple MapKit documentation: `MKPolyline`, `MKPolylineRenderer`, `setVisibleMapRect(_:edgePadding:animated:)` — standard patterns
- Apple Photos documentation: `PHFetchOptions`, `PHImageManager.requestImage(.fastFormat)` — standard patterns
- Apple UserNotifications: `UNNotificationDismissActionIdentifier` — standard dismiss action identifier

### Tertiary (LOW / ASSUMED — flagged in Assumptions Log)
- HealthKit step query pattern (A3) — standard HKStatisticsQuery but authorization state in this codebase unverified
- Timer.publish cancellation behavior (A1) — standard Combine behavior but specific to ZStack conditional rendering

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all frameworks verified in existing codebase
- Architecture patterns: HIGH — all integration points traced to specific file/line numbers
- Pitfalls: HIGH for codebase-specific pitfalls (verified); MEDIUM for iOS framework behavior (assumed)
- Code examples: HIGH for patterns derived from existing code; MEDIUM for new framework calls

**Research date:** 2026-04-06
**Valid until:** 2026-05-06 (stable frameworks — Firebase, MapKit, Photos APIs change slowly)
