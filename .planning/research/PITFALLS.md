# Domain Pitfalls: Nomad iOS Travel App

**Domain:** Native iOS travel logging app (SwiftUI + MapKit + Firebase + CoreLocation)
**Researched:** 2026-04-03
**Confidence:** MEDIUM-HIGH (most claims verified against official docs or Apple Developer Forums; a few items are single-source or forum-only)

---

## Critical Pitfalls

Mistakes that cause rewrites, App Store rejections, or silent production failures.

---

### Pitfall 1: MapKit Does Not Have a "True Globe" Mode in SwiftUI

**What goes wrong:** The project brief says "interactive 3D globe using Apple MapKit." MapKit does not expose a free-rotating 3D globe like Apple Maps shows when fully zoomed out. The `.realistic` elevation style adds 3D terrain rendering but does not transform the map projection into a globe — it remains a flat Mercator projection that tilts. When you zoom out far enough in Apple Maps itself the globe appearance is a native Maps UI behavior, not a MapKit API you can invoke.

**Why it happens:** Developers see the globe in Apple Maps, assume it is an MapKit API surface, and start building around it. The actual globe render is internal to Apple's Maps app. `MKMapView`'s `.flyover` map type gives a 3D perspective at city scale, not globe scale.

**Consequences:** The globe home screen — the entire visual centerpiece of Nomad — may be impossible to build purely with MapKit. Attempting it in simulator may appear to work (simulator has weaker tile fidelity checks) but fail on device.

**Evidence:** An Apple Developer Forums thread (thread/756976) documents: "code works in Xcode simulator but on iPhone it only zooms out to a flat world map." A separate thread (thread/101479) explicitly asks how to view the entire globe in MapKit and the answer is that it is not available.

**Prevention/Mitigation:**
- Prototype the globe zoom-out on a physical device in week 1 before designing anything around it.
- If native MapKit cannot render the globe perspective, evaluate `SceneKit` with a sphere-geometry and a texture-mapped Earth (gives full globe rotation control, but you lose MapKit overlays).
- Alternatively evaluate open-source globe SDKs: **WhirlyGlobe-Maply** (actively maintained, supports MKAnnotation-style overlays). This is a significant dependency decision.
- If the final decision is a flat map with country highlights (still beautiful and practical), design around that — do not over-promise globe to stakeholders until it is confirmed on device.

**Detection:** Run the app on a physical iPhone at zoom level far enough to show entire continents. If projection stays flat, globe mode is not available.

---

### Pitfall 2: Background Location Silently Stops After iOS 16.4

**What goes wrong:** Background location updates stop being delivered to the app even though the user granted "Always" permission and the developer is convinced the code is correct. No crash, no error — location just stops.

**Why it happens:** iOS 16.4 changed the rules for continuous background location. Apps calling `startUpdatingLocation()` that set `desiredAccuracy` to `kCLLocationAccuracyKilometer` or worse, or that set a non-zero `distanceFilter`, are now suspended in the background even with Always permission. Previously this combination worked.

**Specific requirements that must ALL be met (iOS 16.4+):**
- `allowsBackgroundLocationUpdates = true` on the CLLocationManager instance (not just the Info.plist key)
- `distanceFilter = kCLDistanceFilterNone` (or leave unset — any non-zero value can trigger suspension)
- `desiredAccuracy = kCLLocationAccuracyHundredMeters` or better (values like `.kilometer` are insufficient)
- Background Modes entitlement must include "Location updates" in Xcode Signing & Capabilities

**Consequences:** The core trip-detection feature fails silently in production. Users grant permission, expect tracking, get nothing. Battery impact is zero because the app is suspended — but so is all trip data.

**Prevention:**
```swift
let manager = CLLocationManager()
manager.allowsBackgroundLocationUpdates = true
manager.pausesLocationUpdatesAutomatically = false  // or true, but understand its behavior
manager.distanceFilter = kCLDistanceFilterNone
manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
manager.startUpdatingLocation()
```
For the "detect travel then prompt" flow (lower battery cost), use `startMonitoringSignificantLocationChanges()` as the idle baseline — this survives suspension and delivers ~500m resolution updates. Switch to `startUpdatingLocation()` only during an active logging session.

**Detection:** Test on a physical device (not simulator). Lock the screen and leave for 10 minutes. Check if `didUpdateLocations` is still firing. Simulator does not accurately simulate background suspension.

---

### Pitfall 3: Background Location Killed by Watchdog If BGTask Is Not Ended

**What goes wrong:** When using `BGAppRefreshTask` or `BGProcessingTask` for supplementary background work alongside location, failing to call `task.setTaskCompleted(success:)` causes iOS's watchdog to kill the app. Worse, a force-quit by the user overrides background location restarts — unlike a system-initiated kill, a user force-quit prevents iOS from relaunching the app for location events.

**Prevention:**
- Always call `setTaskCompleted` in every code path, including error paths
- Do not mix BGTask framework with always-on location; always-on location does not need BGTask — it runs on the location background mode alone
- Document this in onboarding: tell users not to force-quit the app if they want trip detection

---

### Pitfall 4: App Store Review Will Reject Weak Background Location Justifications

**What goes wrong:** Apple's review team rejects apps where the `NSLocationAlwaysAndWhenInUseUsageDescription` string is vague ("Used to track your location") or where the demonstrated use case does not clearly justify Always permission.

**Specific requirements:**
- The Info.plist key `NSLocationAlwaysUsageDescription` is deprecated — use only `NSLocationAlwaysAndWhenInUseUsageDescription`
- The description must explicitly state what background tracking does: "Nomad tracks your location in the background to automatically detect when you start a trip and log your route, even when the app is closed."
- Apple's guidelines (5.1.1) require Always permission to deliver a feature that is meaningfully degraded without it — you must demonstrate this in the Review Notes
- You must implement a two-step permission flow: request "When In Use" first, then upgrade to "Always" in a contextual moment (not at first launch)

**Mitigation:**
- In App Store Connect Review Notes, write a paragraph describing exactly when background location runs, what data is collected, and why Always permission is needed
- Implement the upgrade prompt at the moment the user first enables "auto-detect trips" in settings, not during onboarding
- Record a demo video showing the background tracking feature in action for the review team

---

### Pitfall 5: Country Polygon Rendering is Slow and Requires Pre-Processing

**What goes wrong:** Loading a world-countries GeoJSON file and creating `MKPolygon` / `MapPolygon` for every country at once causes significant rendering lag or partial render failures. Raw GeoJSON for a country like Russia or Canada contains tens of thousands of coordinate points. Loading all 195 countries simultaneously can exceed 100,000 total points, causing the map to lock up or render polygon edges incorrectly.

**Why it happens:** MapKit's polygon renderer serializes rendering work. Each polygon creates a renderer object. High point-count polygons are expensive to tessellate. Country borders (especially island chains) are complex multi-polygons.

**Specific problems observed:**
- A GeoJSON with 100,000+ points renders "very slowly, flakey, sometimes only partially renders, and causes the map to lock up" (Apple Developer Forums thread/696888)
- At globe zoom levels, country polygons are clipped incorrectly on some devices — vertices near the antimeridian (180° longitude) wrap incorrectly

**Prevention/Mitigation:**
1. **Pre-simplify the GeoJSON offline.** Use `mapshaper` or `turf/simplify` to generate a low-resolution version (tolerance ~0.1–0.5 degrees) for the globe view. Full-resolution borders are unnecessary at globe scale.
2. **Use `MKMultiPolygon`** to batch all countries into a single overlay object — this allows MapKit to batch the rendering call instead of creating per-country renderers.
3. **Render only visited countries as highlighted polygons.** Use a single dimmed base overlay for everything else, avoiding the cost of rendering all 195 countries as distinct objects.
4. **Load and parse GeoJSON off the main thread.** `MKGeoJSONDecoder` can parse on a background queue; add polygons to the map on the main queue after parsing completes.
5. Use the `SwiftSimplify` or `Simplify-Swift` Swift Package for runtime simplification if needed.

**Detection:** Add 50+ countries as MKPolygon on a physical mid-range device (iPhone SE). Measure frame time during initial render.

---

### Pitfall 6: Place Category Data Is Not Available from Reverse Geocoding

**What goes wrong:** The traveler archetype feature depends on place type data ("user visited mostly restaurants, museums, parks"). A common assumption is that `CLGeocoder.reverseGeocodeLocation()` returns place type information from `CLPlacemark`. It does not.

**Reality:**
- `CLPlacemark.areasOfInterest` returns strings (place names) for major landmarks and airports, but returns `nil` for restaurants, shops, and most everyday venues — confirmed on Apple Developer Forums (thread/98129)
- `MKPointOfInterestCategory` (the category enum with cases like `.restaurant`, `.museum`, `.park`) is **only available on `MKMapItem` objects returned from `MKLocalSearch`** — not from reverse geocoding
- There is no CoreLocation API that returns a structured place category for an arbitrary GPS coordinate

**Consequences:** The entire place-categorization and traveler archetype system requires an additional data source. This is a significant architectural decision that affects data costs, offline behavior, and third-party dependencies.

**Options (in order of recommendation):**

| Option | Category Depth | Cost | Works Offline |
|--------|---------------|------|---------------|
| `MKLocalPointsOfInterestRequest` (Apple) | ~30 categories | Free | No |
| Foursquare Places API | ~1000 categories | Free tier: 100K calls/day | No |
| Google Places API | ~100 categories | Paid from ~$0.032/call | No |
| Pre-downloaded OSM data | Extensive | Free | Yes (large) |

**Recommendation:** Use `MKLocalPointsOfInterestRequest` first — query near the user's visited coordinate during active trip logging to get nearby POI categories. Fall back to Foursquare for richer categorization if the Apple category list (~30 types) is too coarse for traveler archetypes. Do not use Google Places: pricing changed in early 2025 (eliminated $200/month free credit, now starts ~$275/month for 100K calls).

**Note:** `MKLocalPointsOfInterestRequest` and `MKLocalSearch` require network access and have rate limits Apple does not publish. Build a local cache so each coordinate is only categorized once.

---

## Moderate Pitfalls

---

### Pitfall 7: Firebase Snapshot Listeners Cause Retain Cycles in SwiftUI ViewModels

**What goes wrong:** A `ViewModel` class adds a Firestore `addSnapshotListener` and stores the registration handle. When the SwiftUI view is dismissed, `deinit` on the ViewModel is never called because the listener closure captures `self` strongly, creating a retain cycle. Over time (navigating in and out of trip views), memory grows unboundedly.

**Why it happens:** `addSnapshotListener` takes a closure. The closure captures `self` (the ViewModel). The listener registration is stored on `self`. Circular reference → neither is ever released.

**Prevention:**
```swift
class TripViewModel: ObservableObject {
    private var listenerRegistration: ListenerRegistration?

    func startListening(tripId: String) {
        listenerRegistration = Firestore.firestore()
            .collection("trips").document(tripId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                // update state
            }
    }

    deinit {
        listenerRegistration?.remove()
    }
}
```

**Additional rule:** Never attach a snapshot listener to a view that can appear multiple times (e.g., each trip card in a list). Each appearance creates a new listener; if `deinit` is not reliably called, listeners accumulate. Attach trip-level listeners only to the detail view, not the card.

**SwiftUI-specific trap:** `@StateObject` does not guarantee `deinit` is called when a view disappears if the parent view keeps the StateObject alive. If the ViewModel holds a listener and is owned by a parent, it will not be released until the parent is released. Use `.onDisappear` to explicitly call `listenerRegistration?.remove()` as a safety net.

---

### Pitfall 8: Firestore WebSocket Errors on Background/Foreground Transitions

**What goes wrong:** Approximately 1 in 10 app launches, or after returning from background, Firestore throws `NSPOSIXErrorDomain Code=89 Operation canceled` errors. The underlying web socket is torn down when the app enters background and occasionally does not reconnect cleanly.

**Prevention:**
- Enable Firestore offline persistence (`Firestore.firestore().settings.cacheSettings = PersistentCacheSettings()`) so read queries succeed while the SDK reconnects
- Do not treat every Firestore error as user-visible — distinguish between connectivity errors (transient, retry) and auth/permission errors (user must act)
- Test reconnection behavior explicitly: put app to background for 5 minutes, return, verify listener fires with fresh data

---

### Pitfall 9: SwiftUI `.sheet()` Touch Events Break After Background/Foreground Cycle

**What goes wrong:** After a sheet is open when the app enters background, and the user returns and dismisses the sheet, buttons near the top of the underlying view (near the status bar) stop responding to taps. The view renders correctly but touch events hit dead zones.

**Why it happens:** The underlying `UIView`'s transform misaligns with its touch event coordinate system during the lifecycle transition. This is an iOS 16+ bug confirmed with reproduction steps: requires `.sheet()` without custom detents (or with `.large`), a `ScrollView` with `.ignoresSafeArea()`, and buttons near the status bar.

**Consequences:** The globe view with top-positioned controls (any button in the top ~80pt) becomes untappable after this sequence. Given Nomad's always-visible globe backdrop and potential for the user to have the app open when receiving a notification and backgrounding, this will affect real users.

**Mitigation:**
- Use `presentationDetents` with at least one explicit detent (e.g., `.medium`, `.fraction(0.5)`) — this changes the sheet layout path and avoids the bug
- Force-recalculate the root view's transform on sheet dismiss (the workaround described at juniperphoton.substack.com): set `rootViewController.view.transform.ty = 1`, then immediately back to `.identity`
- File an Apple Feedback with a repro case — this may be fixed in a future iOS release

---

### Pitfall 10: Multiple Stacked Bottom Sheets — Only One `.sheet()` Can Present at a Time

**What goes wrong:** Attempting to present a second sheet from within a sheet (sheet → detail sheet → deeper detail sheet) requires careful architecture. SwiftUI only allows one sheet to be presented per view at a time. Calling `.sheet()` from a view that is itself inside a sheet often does nothing silently, or causes a runtime warning: "Attempt to present ... whose view is not in the window hierarchy."

**Why it happens:** Each `.sheet()` modifier is anchored to the view it's attached to. Inside a presented sheet, the sheet's root view must be the anchor for the next presentation — but this requires careful binding management.

**Mitigation:**
- Use a coordinator/router pattern. A shared `NavigationRouter` object (injected via `.environmentObject`) holds the navigation stack state and presents sheets from the window root, not from within nested sheets.
- Or use `NavigationStack` inside the sheet for in-sheet drill-down navigation — this avoids nested sheet presentation entirely and gives back-swipe gesture handling automatically.
- Avoid the pattern: `SheetA` → `.sheet()` → `SheetB` → `.sheet()` → `SheetC`. Instead: `SheetA` → `NavigationStack` push → `SheetB` content → push → `SheetC` content.

---

### Pitfall 11: Apple Photos Limited Access Mode — Asset Identifiers Are Unavailable

**What goes wrong:** When the user grants "Limited" access to Photos (selecting specific photos rather than "Full Access"), your app cannot use `PHAsset` local identifiers to look up photos by location or date. The `PHAssetCollection` containing the user's "selected" photos is the only accessible pool.

**Specific behavior:**
- `PHPickerViewController` shows the full photo library regardless of limited/full access mode — users can pick any photo
- But if your app tries to query `PHAsset` objects by identifier (e.g., to find photos taken at a GPS coordinate), those identifiers will not match if the user is in Limited mode and has not selected those photos
- `PHAuthorizationStatus.limited` is a distinct status from `.authorized` — check for it explicitly

**Consequences for Nomad:** The "scrollable photo gallery" for a trip location relies on finding Photos by location/date. In limited mode, this query will silently return zero results even if the user has photos from that trip.

**Mitigation:**
- Show a "Manage Photo Access" prompt (using `PHPhotoLibrary.shared().presentLimitedLibraryPicker(from:)`) when photo gallery returns zero results, explaining that limited access may be hiding trip photos
- Provide an explicit "Add Photos to This Trip" flow using `PHPickerViewController` as an alternative path — this always works regardless of access level
- At onboarding, request full library access and show a clear explanation of why full access provides the best experience (trip galleries auto-populated from location data)

---

### Pitfall 12: GPS Polyline Performance Degrades With Unthrottled High-Frequency Updates

**What goes wrong:** If the CLLocationManager is configured with `kCLDistanceFilterNone` and `kCLLocationAccuracyBest` during active trip logging, it can generate 1 point per second on foot (3,600 points/hour). Rendering this as a single `MKPolyline` causes frame drops when the map redraws — especially when zooming or panning over the route.

**Observed thresholds:** In testing, ~1,000 points causes slight pan delays; ~3,000 points causes visible lag on older hardware (reported on Apple Developer Forums).

**Prevention:**
1. **Throttle at collection:** Use `distanceFilter = 5` (meters) during active logging. At walking pace (~1.4 m/s), this gives ~1 point every 3.5 seconds — far fewer points with no perceptible route quality loss.
2. **Simplify before render:** Apply the Ramer-Douglas-Peucker algorithm before constructing `MKPolyline`. Use `SwiftSimplify` (Swift Package) or `Simplify-Swift`. Choose tolerance dynamically based on map zoom level.
3. **Do not recreate the polyline on every location update.** Batch updates: accumulate new points in a buffer, then replace the polyline every N points or every N seconds.
4. **Store raw points in Firestore, render simplified points in MapKit.** The source-of-truth retains full resolution; what's shown is zoom-level-appropriate.

---

### Pitfall 13: HealthKit Requires Privacy Policy URL in App Store Connect — Not Just a String

**What goes wrong:** Submitting an app that uses HealthKit (for step data) without a valid, publicly accessible privacy policy URL in App Store Connect causes automatic rejection. The privacy policy must specifically mention HealthKit/health data use. A placeholder URL or a URL that returns 404 will fail review.

**Entitlement requirements:**
- Add `com.apple.developer.healthkit` entitlement (Xcode: Signing & Capabilities → HealthKit)
- Add `NSHealthShareUsageDescription` to Info.plist (reading steps)
- Do NOT add `NSHealthUpdateUsageDescription` unless writing data back to Health
- The HealthKit entitlement requires developer program enrollment — it cannot be tested on simulator (HealthKit APIs return `HKError.errorHealthDataUnavailable` on simulator)

**Data use restrictions:** Apple's guidelines (5.1.1.h) prohibit using HealthKit data for advertising or third-party data mining. Firebase Analytics must NOT receive step counts or health data. If you log step data to Firestore for display, ensure it is not flowing into any analytics pipeline.

**Mitigation:**
- Create a real privacy policy page before App Store submission (not during)
- Explicitly state "We use HealthKit to read step count data. This data is not shared with third parties and is not used for advertising."
- Test HealthKit flows on a physical device only

---

## Minor Pitfalls

---

### Pitfall 14: `.realistic` Elevation Requires A12 Chip or Later

**What goes wrong:** `MapStyle.standard(elevation: .realistic)` silently falls back to `.flat` on devices older than iPhone XS (A12). There is no API callback indicating the fallback occurred.

**Prevention:** Do not design visual experiences that depend on realistic elevation being present. Build with `.automatic` as the baseline; `.realistic` is an enhancement. Test on an older device (iPhone X or SE 2nd gen if targeting iOS 16).

---

### Pitfall 15: Firestore Offline Query Scans Entire Cache

**What goes wrong:** When the device is offline, Firestore performs full collection scans in the local cache. If a user has been offline for a long time and has accumulated data, reads can be noticeably slow.

**Prevention:** Enable `FirestoreSettings` with `PersistentCacheSettings` and allow auto-indexing (`persistentCacheIndexAutoCreation(db:)`). This dramatically improves offline query performance at the cost of slightly more disk usage.

---

### Pitfall 16: `NSLocationAlwaysUsageDescription` Still Required by Some Toolchains

**What goes wrong:** `NSLocationAlwaysUsageDescription` is deprecated in favor of `NSLocationAlwaysAndWhenInUseUsageDescription`, but some Xcode/SDK configurations still warn or fail if only one is present. Include both keys in Info.plist pointing to the same string to avoid silent gaps.

---

### Pitfall 17: Foursquare Free Tier Requires Attribution

**What goes wrong:** If you use Foursquare Places API for place categorization, the free tier requires visible attribution ("Powered by Foursquare") in the UI wherever venue data appears. Failure to do so violates their ToS and can result in API key revocation.

**Prevention:** Design the place detail view with an attribution slot from day one. Consider whether `MKLocalPointsOfInterestRequest` with ~30 Apple categories is sufficient to avoid the third-party dependency entirely.

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| Globe home screen | MapKit may not support true globe mode | Prototype on device in Phase 1, week 1 |
| Background trip detection | iOS 16.4 silent suspension | Use significantLocationChanges as baseline |
| Country highlights | GeoJSON polygon performance | Pre-simplify offline, use MKMultiPolygon |
| Place categorization | No category from reverse geocoding | Decide on MKLocalPointsOfInterestRequest vs Foursquare before first sprint |
| Trip route display | Polyline lag at 3,000+ points | Apply RDP simplification before MKPolyline |
| Photo gallery per trip | PHAsset queries fail in limited access | Build picker-based fallback from the start |
| App Store submission | Background location rejection | Write specific description, use two-step permission flow |
| HealthKit steps | Simulator incompatibility | Steps-related flows require physical device |
| Bottom sheet stack | Only one .sheet() per view hierarchy | Use NavigationStack inside sheets for drill-down |

---

## Sources

- Apple Developer Forums — MapKit globe on iPhone: https://developer.apple.com/forums/thread/756976
- Apple Developer Forums — Globe view availability: https://developer.apple.com/forums/thread/101479
- Apple Developer Forums — CLPlacemark place types: https://developer.apple.com/forums/thread/649548
- Apple Developer Forums — CLPlacemark areasOfInterest nil: https://developer.apple.com/forums/thread/98129
- iOS 16.4 Background Location Changes (Cropsly): https://cropsly.com/blog/location-updates-changes-in-ios-16-4/
- Apple Energy Efficiency Guide — Location Best Practices: https://developer.apple.com/library/archive/documentation/Performance/Conceptual/EnergyGuide-iOS/LocationBestPractices.html
- Apple Documentation — Handling Location Updates in Background: https://developer.apple.com/documentation/corelocation/handling-location-updates-in-the-background
- Apple Documentation — MKPointOfInterestCategory: https://developer.apple.com/documentation/mapkit/mkpointofinterestcategory
- Apple WWDC21 — Improve Access to Photos: https://developer.apple.com/videos/play/wwdc2021/10046/
- SwiftUI .sheet() pitfalls (Juniperphoton): https://juniperphoton.substack.com/p/pro-to-swiftuisheet-pitfalls-and
- Firebase iOS SDK — Memory Leak issue: https://github.com/firebase/firebase-ios-sdk/issues/2607
- Firebase + SwiftUI Lifecycle: https://peterfriese.dev/blog/2020/swiftui-new-app-lifecycle-firebase/
- SwiftSimplify (polyline simplification): https://github.com/malcommac/SwiftSimplify
- Simplify-Swift: https://github.com/tomislav/Simplify-Swift
- Apple App Store Review Guidelines (5.1.1): https://developer.apple.com/app-store/review/guidelines/
- Apple HealthKit — Protecting User Privacy: https://developer.apple.com/documentation/healthkit/protecting-user-privacy
- Foursquare vs Google Places comparison: https://slashdot.org/software/comparison/Foursquare-vs-Google-Places-API/
- MapKit polygon performance (Apple Forums): https://developer.apple.com/forums/thread/696888
- Background location suspension discussion: https://developer.apple.com/forums/thread/69152
