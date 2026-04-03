# Technology Stack: Nomad iOS App

**Project:** Nomad — native iOS travel logging app
**Researched:** 2026-04-03
**Overall confidence:** MEDIUM-HIGH (most areas verified against official docs or recent developer articles; globe rendering area has a significant known limitation documented below)

---

## Critical Upfront Warning: MapKit Does NOT Render a Globe on iPhone

The single most important finding in this research: **MapKit's SwiftUI `Map` view does not render as a spinning 3D globe on iPhone.** The `.standard` map style renders as a flat 2D map regardless of zoom level. The `.imagery` and `.hybrid` styles with realistic elevation give 3D terrain, but not a full-sphere globe view.

Before iOS 16, `MKMapType.satelliteFlyover` and `MKMapType.hybridFlyover` could produce globe-like rendering on macOS and some iPad contexts, but these are deprecated as of iOS 16 and have no direct SwiftUI replacement that renders a true spherical earth. Apple developer forums (threads 719516 and 760542) confirm this gap — no replacement API exists in MapKit as of early 2026.

**Decision required: use SceneKit/RealityKit for the globe, use MapKit for everything else (route maps, trip detail views, POI search).**

This split is covered in detail in the Globe Rendering section below.

---

## Recommended Stack

### Core Framework

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| SwiftUI | iOS 17+ minimum | All UI | Declarative, MapKit for SwiftUI requires iOS 17 for full feature set; `presentationDetents` for bottom sheets available since iOS 16 |
| Swift | 5.10+ (Xcode 16) | Language | Structured concurrency (async/await) is stable and required for CLLocationUpdate, Firebase v11+ APIs |
| Minimum deployment target | iOS 17.0 | — | CLLocationUpdate (modern location API), Firebase 12.x minimum iOS 15 but iOS 17 gives you CLBackgroundActivitySession, CLServiceSession; targeting 17 avoids bridging pain |

**Do not target iOS 16.** Firebase SDK 12.x minimum is iOS 15, but the CoreLocation modern APIs behave correctly only on iOS 18+ for `CLLocationUpdate`; targeting iOS 17 is a reasonable floor. iOS 17 gives MapKit for SwiftUI maturity. If you want to use `CLLocationUpdate` properly, plan for iOS 18 minimum or fall back to `CLLocationManager` (see Location section).

### Globe Rendering (Home View)

| Technology | Purpose | Notes |
|------------|---------|-------|
| RealityKit (iOS) | Interactive 3D globe sphere | SceneKit was soft-deprecated at WWDC 2025 — new development should use RealityKit |
| ModelEntity + MeshResource.generateSphere | Globe sphere geometry | Standard RealityKit primitive; wrap with Earth diffuse texture |
| NASA Blue Marble texture | Earth surface visual | High-res, freely usable, no license issues for non-commercial; use the 8K or 4K PNG variant |
| GeoJSON for country boundaries | Country highlight overlay | ISO 3166-1 country polygon data; render overlay as a texture or geometry layer on sphere surface |
| RealityView (iOS 18+) or ARView (wrapped) | SwiftUI integration | `RealityView` is the correct SwiftUI-native container in iOS 18+; for iOS 17 support wrap via `UIViewRepresentable` with `ARView` |

**What NOT to use:**
- `SceneKit (SCNScene/SCNSphere)` — soft-deprecated at WWDC 2025. Works but Apple has put it in maintenance-only mode. New projects should not use it.
- `MapKit Map view` for the globe — confirmed by Apple forums: the `.standard` map style does not render as a spherical globe on iPhone. Do not attempt to use MapKit for the globe home view.
- `MapKit JS` — web-based, not available natively in UIKit/SwiftUI context.

**Globe country highlight approach:** Convert country GeoJSON polygons to coordinates, project onto the sphere surface using spherical trigonometry (latitude/longitude to 3D Cartesian), render as a `ModelEntity` with emissive material or draw into the diffuse texture. The SceneKit-based SwiftGlobe open source project (github.com/dmojdehi/SwiftGlobe) is a good reference even if you implement in RealityKit.

**Implementation note:** `RealityView` requires iOS 18. For iOS 17 support, wrap an `ARView` (with AR disabled, use `.nonAR` camera mode) in a `UIViewRepresentable`. This is the standard pattern and works well. Plan to migrate to `RealityView` once you raise the minimum to iOS 18.

### MapKit (Trip Detail, Route Maps, POI)

MapKit is the right tool for everything that is NOT the globe home view.

| Technology | API | Purpose |
|------------|-----|---------|
| MapKit for SwiftUI | `Map { }` with `MapPolyline` | Route trace visualization — Strava-style GPS line on a map |
| `MapPolyline` | `.stroke(color, lineWidth:)` | Draw GPS route as styled polyline; no `UIViewRepresentable` needed in iOS 17+ |
| `MKStandardMapConfiguration` with `elevationStyle: .realistic` | via `UIViewRepresentable` wrapping `MKMapView` | 3D terrain for trip detail maps — must use `MKMapView.preferredConfiguration` not SwiftUI modifiers (the SwiftUI `Map` view does not expose `preferredConfiguration`) |
| `MKLocalSearch` with `MKPointOfInterestFilter` | POI search | Fetch nearby places by category; use `MKPointOfInterestCategory` for traveler archetype categorization |
| `MKMapItem` | Place metadata | Contains `pointOfInterestCategory`, `name`, `phoneNumber`, `url`, `placemark` |
| `CLGeocoder.reverseGeocodeLocation` | Reverse geocoding | Convert GPS coordinates to place names and country; returns `CLPlacemark` with `.isoCountryCode`, `.country`, `.locality`, `.subLocality` |

**`MKPointOfInterestCategory` values available for archetype mapping** (partial list — full list in Apple docs):
`.restaurant`, `.cafe`, `.bakery`, `.brewery`, `.winery`, `.nightlife`, `.bar`, `.hotel`, `.museum`, `.theater`, `.movieTheater`, `.library`, `.beach`, `.nationalPark`, `.park`, `.campground`, `.hiking`, `.skiing`, `.fitnessCenter`, `.gym`, `.spa`, `.airport`, `.publicTransport`, `.hospital`, `.pharmacy`, `.gasStation`, `.parking`, `.store`, `.university`, `.stadium`

These map cleanly onto traveler archetypes (foodie = restaurant/cafe/bakery, culture = museum/theater, outdoors = beach/nationalPark/hiking, nightlife = bar/brewery/nightlife).

**What NOT to use:**
- The deprecated `MKMapType` enum — deprecated in iOS 16, use `MKStandardMapConfiguration`, `MKHybridMapConfiguration`, `MKImageryMapConfiguration` via `MKMapView.preferredConfiguration` instead.
- `MapKit JS` — web-only.
- Google Maps SDK — contradicts the Apple-ecosystem-first design priority and adds a third-party dependency.

### Location Tracking (CoreLocation)

| Technology | API | Purpose | iOS Requirement |
|------------|-----|---------|-----------------|
| `CLLocationManager` | Traditional, proven | Always-on background GPS tracking | iOS 14+ |
| `CLLocationUpdate.liveUpdates(_:)` | Modern async sequence | Cleaner Swift concurrency integration | iOS 17+ (but has bugs; reliable only on iOS 18+) |
| `CLBackgroundActivitySession` | Background session management | Keeps location updates alive when app is backgrounded | iOS 17+ |
| `CLServiceSession` | Permission management | Modern replacement for imperative `.requestAlwaysAuthorization()` | iOS 18+ |
| `CLMonitor` | Geofencing / home city detection | Detect when user leaves home region to trigger trip logging | iOS 17+ |

**Recommended approach for Nomad:** Use `CLLocationManager` as the primary location engine, not `CLLocationUpdate`. Rationale from research: `CLLocationUpdate` has per-version behavioral inconsistencies, lacks `distanceFilter` and `desiredAccuracy`, and the `twocentstudios.com` 2024 deep-dive explicitly recommends `CLLocationManager` for core-location apps.

**Battery optimization settings (use these):**

```swift
// Active trip recording — high accuracy, significant battery cost
locationManager.desiredAccuracy = kCLLocationAccuracyBest
locationManager.distanceFilter = 10  // meters — avoid GPS noise

// Background / standby — lower accuracy to preserve battery
locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters

// Auto-pause when stationary
locationManager.pausesLocationUpdatesAutomatically = true
locationManager.activityType = .fitness  // or .automotiveNavigation when in car

// Background mode
locationManager.allowsBackgroundLocationUpdates = true
locationManager.showsBackgroundLocationIndicator = true  // required for App Store review
```

**For home city detection (trip trigger):** Use `CLMonitor` with a circular region centered on the user's home city coordinate. When the user exits the region, send a notification asking if they want to log a trip. Region entry/exit notifications arrive within 3-5 minutes on average — acceptable latency for this use case.

**What NOT to use:**
- Significant location change monitoring (`startMonitoringSignificantLocationChanges`) alone — 500m+ granularity, too coarse for route recording.
- `CLLocationUpdate` as the primary engine on iOS 17 — unpredictable behavior, missing filter properties. Use only if targeting iOS 18+ exclusively.
- Always-on `kCLLocationAccuracyBest` when not actively recording — battery drain is severe.

**Info.plist keys required:**
- `NSLocationAlwaysAndWhenInUseUsageDescription` — always-on permission
- `NSLocationWhenInUseUsageDescription` — fallback
- `UIBackgroundModes` → `location`

**Permission flow:** Request `whenInUse` first during onboarding, then upgrade to `always` when user taps "enable background tracking." Do not cold-request `always` — App Store reviewers flag this.

### Firebase Backend

| Component | Version | Purpose | Notes |
|-----------|---------|---------|-------|
| Firebase iOS SDK | 12.x (current: 12.11.0 as of March 2026) | Entire Firebase surface | Install via Swift Package Manager — CocoaPods deprecated for Firebase v9+ |
| FirebaseAuth | included | User authentication | Sign in with Apple required if auth is in-app; Firebase Auth supports Sign in with Apple natively |
| FirebaseFirestore | included | Trip data, user profiles, social graph | Offline persistence enabled by default on iOS |
| FirebaseStorage | included | Photo storage (compressed trip images) | Do not store full-resolution PHAsset originals; compress before upload |

**Installation:** Use Swift Package Manager with the URL `https://github.com/firebase/firebase-ios-sdk`. Do NOT use CocoaPods — deprecated since v9.

**SwiftUI integration gotcha:** Firebase requires an `AppDelegate` for initialization. In a SwiftUI lifecycle app:

```swift
@main
struct NomadApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    // ...
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        FirebaseApp.configure()
        return true
    }
}
```

Do NOT skip this — Firebase will not initialize correctly without it in SwiftUI lifecycle apps.

**Firebase v11 breaking changes (migrating from v10 or earlier):**
- `FirebaseFirestoreSwift` module removed — import `FirebaseFirestore` directly; Codable support is now built in
- `Timestamp` moved: was `FirebaseFirestoreSwift.Timestamp` → now `FirebaseCore.Timestamp`
- LRU garbage collector is now the default for Firestore offline cache (was eager GC)
- Minimum iOS raised to iOS 15 in v12.0 — not an issue if targeting iOS 17+

**Firestore data shape gotchas:**
- Max 1 write/second per document — do not use a single document for counters (e.g., total trip count). Use server-side increment or sharding.
- Default offline cache: 40 MB. For a travel app with photos, configure explicitly:
  ```swift
  let settings = FirestoreSettings()
  settings.cacheSettings = PersistentCacheSettings(sizeBytes: 100 * 1024 * 1024 as NSNumber)
  Firestore.firestore().settings = settings
  ```
- Firestore has no full-text search — do not build place name search against Firestore directly. Use `MKLocalSearch` for place discovery instead.

**Firebase Storage for photos:** Store only compressed previews (max 1024px long edge, JPEG quality 0.8). Store the local PHAsset identifier as metadata so you can always fetch the full-res original from the device's photo library. This avoids large Storage bills and slow upload times.

**What NOT to use:**
- Firebase Realtime Database — Firestore is the current standard; Realtime Database is a legacy product
- Firebase Remote Config or Analytics in v1 — unnecessary complexity; add only when needed
- CocoaPods for dependency management

### Photos Framework

| Technology | API | Purpose |
|------------|-----|---------|
| PhotoKit (`Photos.framework`) | `PHFetchOptions`, `PHAsset`, `PHImageManager` | Fetch photos filtered by date range and location for trip gallery |
| `PHAsset` properties | `.creationDate`, `.location` | Match photos to trip time window and GPS bounding box |
| `PHImageManager.requestImage` | Async image loading | Load thumbnails and full-size images; use `PHImageRequestOptions` to control quality/delivery |
| `PHPhotoLibrary.requestAuthorization(for: .readWrite)` | Permission | Request full library access; iOS 14+ also has limited access — handle both |

**Access pattern for trip galleries:**

```swift
// Fetch photos within a time window
let options = PHFetchOptions()
options.predicate = NSPredicate(
    format: "creationDate >= %@ AND creationDate <= %@",
    tripStart as NSDate,
    tripEnd as NSDate
)
options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
let assets = PHAsset.fetchAssets(with: .image, options: options)
```

Then filter by GPS bounding box using `asset.location?.coordinate` to match photos to the specific trip route.

**iOS 17 location metadata gotcha:** In iOS 17, the system photo picker's new Options menu lets users strip location metadata before sharing via `PHPickerViewController`. If you use `PHPickerViewController` for photo import (not recommended for this use case), you may receive images without location data. Use direct `PHPhotoLibrary` access with full authorization instead — this preserves all metadata including location.

**Limited library access (iOS 14+):** If the user grants limited access, `PHAsset.fetchAssets` only returns the selected subset. Handle this gracefully — prompt users to grant full access in Settings, or work with whatever is available. Do not crash or show empty states without explanation.

**Do NOT use `UIImagePickerController`** — deprecated in iOS 14. Use `PHPhotoLibrary` API directly for this use case (full library scan tied to trips), not `PHPickerViewController` (which is for user-driven single-image selection).

### HealthKit

| Technology | API | Purpose |
|------------|-----|---------|
| `HealthKit.framework` | `HKHealthStore` | Step count access |
| `HKStatisticsQuery` | Per-trip step total | Fetch sum of steps between trip start and end timestamps |
| `HKStatisticsCollectionQuery` | Hourly breakdown | If showing per-hour steps on trip detail |
| `HKQuantityType(.stepCount)` | Step count data type | The specific quantity identifier |

**Implementation pattern:**

```swift
let stepType = HKQuantityType(.stepCount)
let predicate = HKQuery.predicateForSamples(
    withStart: tripStart,
    end: tripEnd,
    options: .strictStartDate
)
let query = HKStatisticsQuery(quantityType: stepType,
                               quantitySamplePredicate: predicate,
                               options: .cumulativeSum) { _, result, error in
    let steps = result?.sumQuantity()?.doubleValue(for: .count()) ?? 0
}
healthStore.execute(query)
```

**Key constraints:**
- HealthKit is unavailable on iPad — the app is iPhone-only so this is fine, but do not test HealthKit on simulator (no health data).
- Always test HealthKit on a real device.
- Request only `HKObjectType.quantityType(forIdentifier: .stepCount)` — do not request broader types; App Store reviewers reject unnecessary HealthKit permissions.
- `Info.plist` key required: `NSHealthShareUsageDescription`

**Do NOT request write permission** — Nomad reads steps, it does not write health data.

### SwiftUI Navigation and Bottom Sheet Pattern

| Technology | API | Purpose |
|------------|-----|---------|
| `.sheet(isPresented:)` with `.presentationDetents` | Native SwiftUI | Bottom sheet with snap points |
| `.presentationDetents([.medium, .large, .fraction(0.4)])` | iOS 16+ | Define sheet snap heights |
| `.presentationDragIndicator(.visible)` | iOS 16+ | Show drag handle on sheets |
| `.presentationBackgroundInteraction(.enabled)` | iOS 16.4+ | Allow interacting with globe behind the sheet |
| Router pattern (centralized state) | Custom | Manage stacked sheets without nesting limits |

**The stacked sheet problem:** SwiftUI only supports one active `.sheet` per view. Presenting a second sheet from inside the first sheet's content is the correct pattern, not chaining `.sheet` modifiers on the same view (which triggers runtime errors). Use a centralized `SheetRouter` observable object:

```swift
@Observable class SheetRouter {
    var presentedSheet: SheetDestination?
    var presentedDetailSheet: SheetDestination?

    enum SheetDestination {
        case profile
        case tripDetail(Trip)
        case travelerPassport
    }
}
```

The root view presents `presentedSheet`; the first sheet's content presents `presentedDetailSheet`. This is the pattern used in production apps (e.g., Icecubes Mastodon client).

**Globe as persistent background:** The globe `RealityView`/`ARView` lives at the root level. Sheets float above it with `presentationBackgroundInteraction(.enabled(upThrough: .medium))` so the globe remains interactive when the sheet is at medium detent. At `.large` detent the globe is obscured — this is acceptable behavior.

**Do NOT use `NavigationStack` for sheet content** without removing the navigation background. If you push views inside a sheet using `NavigationStack`, the navigation background creates an opaque layer that blocks the globe behind it. Use `.containerBackground(.clear, for: .navigation)` to make it transparent, or avoid `NavigationStack` inside sheets entirely and use custom back-navigation patterns.

### Supporting Libraries

| Library | Purpose | Install | Notes |
|---------|---------|---------|-------|
| None recommended for v1 | — | — | — |

**Avoid third-party mapping libraries** (Mapbox, Google Maps) — contradicts the Apple-first constraint and the MapKit decision.

**Avoid third-party bottom sheet libraries** (BottomSheet by lucaszischka, etc.) — `presentationDetents` in iOS 16+ handles all required use cases natively.

**Avoid Combine** — use Swift's native `async/await` and `AsyncSequence`. Combine is not deprecated but SwiftUI+Concurrency integration is cleaner with structured concurrency.

**Consider for v2 (not v1):**
- `FirebaseMessaging` — push notifications for trip detection prompts
- `FirebaseCrashlytics` — crash reporting

---

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| Globe rendering | RealityKit | MapKit | MapKit confirmed by Apple forums to NOT render globe on iPhone; `.standard` stays flat |
| Globe rendering | RealityKit | SceneKit | SceneKit soft-deprecated at WWDC 2025; RealityKit is the successor |
| Location engine | `CLLocationManager` | `CLLocationUpdate` | `CLLocationUpdate` lacks `distanceFilter`, has iOS 17 accuracy bugs, not suitable as primary engine |
| Firebase install | Swift Package Manager | CocoaPods | Firebase deprecated the CocoaPods `Firebase` pod in v9+ |
| Photo import | `PHPhotoLibrary` direct | `PHPickerViewController` | Picker strips location metadata in iOS 17; direct library access preserves it |
| Navigation | Custom `SheetRouter` | NavigationSplitView | NavigationSplitView is for iPad sidebar layouts, not the stacked-sheet-over-globe pattern |
| Font loading | SwiftUI Font with custom | Third-party font library | SwiftUI handles custom fonts natively via Info.plist registration; no library needed |

---

## iOS Version Compatibility Matrix

| Feature | iOS 15 | iOS 16 | iOS 17 | iOS 18 |
|---------|--------|--------|--------|--------|
| `MapPolyline` in SwiftUI | No | Yes | Yes | Yes |
| `presentationDetents` | No | Yes | Yes | Yes |
| `presentationBackgroundInteraction` | No | No (16.4) | Yes | Yes |
| `CLLocationUpdate` | No | No | Partial (buggy accuracy) | Full |
| `CLBackgroundActivitySession` | No | No | Yes | Yes |
| `CLServiceSession` | No | No | No | Yes |
| `RealityView` | No | No | No | Yes |
| Firebase 12.x minimum | Yes | Yes | Yes | Yes |

**Recommended minimum deployment target: iOS 17.0.** This gives you `MapPolyline`, `presentationDetents`, `CLBackgroundActivitySession`, and MapKit for SwiftUI maturity. Use `UIViewRepresentable` wrapping `ARView` (not `RealityView`) for the globe on iOS 17.

When you raise the floor to iOS 18 (recommended in 6-12 months), migrate to `RealityView` and `CLServiceSession`.

---

## Installation

```bash
# Firebase via Swift Package Manager
# In Xcode: File → Add Package Dependencies
# URL: https://github.com/firebase/firebase-ios-sdk
# Add: FirebaseAuth, FirebaseFirestore, FirebaseStorage

# No other third-party packages recommended for v1
```

**Info.plist entries required:**

```xml
<!-- Location -->
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Nomad tracks your location in the background to automatically log your trips and build your travel map.</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>Nomad uses your location to show where you are on the map.</string>
<key>UIBackgroundModes</key>
<array>
    <string>location</string>
</array>

<!-- HealthKit -->
<key>NSHealthShareUsageDescription</key>
<string>Nomad reads your step count to add walking stats to your trip logs.</string>

<!-- Photos -->
<key>NSPhotoLibraryUsageDescription</key>
<string>Nomad accesses your photo library to attach photos from your trips to your travel log.</string>
```

**Signing & Capabilities required:**
- HealthKit
- Background Modes → Location updates
- Push Notifications (when you add trip-detection prompts)

---

## Open Questions / Flags for Implementation Phases

1. **Globe country highlight rendering** — The approach of projecting GeoJSON polygons onto a RealityKit sphere will require non-trivial geometry work. Plan a dedicated technical spike for this. Complexity: HIGH.

2. **`RealityView` vs `ARView` wrapping** — If minimum is iOS 17, you must use `UIViewRepresentable` + `ARView`. If you decide iOS 18 is acceptable, `RealityView` is much cleaner. This should be decided before Phase 1 of globe implementation.

3. **Sign in with Apple** — Firebase Auth supports it. Apple requires Sign in with Apple when any other social auth is offered. If email/password auth is the only method, it is not required. Decide auth strategy early.

4. **Firestore data model for location** — Firestore has no native geo-query support. Storing trip GPS traces as arrays of coordinates in a single document works for small routes; for long multi-hour traces consider GeoFirestore or chunking. Research before designing the data model.

5. **Camera permission** — Not listed in requirements, but if you add in-app photo capture (vs. import from library), `NSCameraUsageDescription` will be needed.

---

## Sources

- Apple Developer Forums: MapKit standard style does not render globe on iPhone — https://developer.apple.com/forums/thread/760542
- Apple Developer Forums: No replacement for MKMapType globe view in iOS 16 — https://developer.apple.com/forums/thread/719516
- WWDC 2023: Meet MapKit for SwiftUI — https://developer.apple.com/videos/play/wwdc2023/10043/
- WWDC 2023: Discover streamlined location updates — https://developer.apple.com/videos/play/wwdc2023/10180/
- WWDC 2024: What's new in location authorization — https://developer.apple.com/videos/play/wwdc2024/10212/
- WWDC 2025: Bring your SceneKit project to RealityKit — https://developer.apple.com/videos/play/wwdc2025/288/
- CoreLocation modern API tips (December 2024) — https://twocentstudios.com/2024/12/02/core-location-modern-api-tips/
- Firebase Apple SDK release notes — https://firebase.google.com/support/release-notes/ios
- Firebase: Add Firebase to your Apple project — https://firebase.google.com/docs/ios/setup
- Firebase: Access data offline (Firestore) — https://firebase.google.com/docs/firestore/manage-data/enable-offline
- Apple: Handling location updates in the background — https://developer.apple.com/documentation/corelocation/handling-location-updates-in-the-background
- Apple: Adopting live updates in Core Location — https://developer.apple.com/documentation/corelocation/adopting-live-updates-in-core-location
- Apple: MKPointOfInterestCategory — https://developer.apple.com/documentation/mapkit/mkpointofinterestcategory
- Apple: MapPolyline in SwiftUI — https://www.createwithswift.com/using-mappolyline-overlays-in-mapkit-with-swiftui/
- Stacked sheet navigation pattern — https://blog.martinp7r.com/posts/decoupled-stacked-sheet-navigation-with-multiple-modals-in-swiftui/
- RealityKit 3D globe with SceneKit reference — https://medium.com/@udaniFernando/behind-the-scenes-creating-a-3d-earth-globe-in-swiftui-with-scenekit-cdff9d838058
- SwiftGlobe open source reference — https://github.com/dmojdehi/SwiftGlobe
- WWDC 2025: SceneKit soft deprecation — https://dev.to/arshtechpro/wwdc-2025-scenekit-deprecation-and-realitykit-migration-a-comprehensive-guide-for-ios-developers-o26
- New MapKit configurations with SwiftUI — https://holyswift.app/new-mapkit-configurations-with-swiftui/
- PHPickerViewController and location metadata (iOS 17) — https://developer.apple.com/forums/thread/660696
- HealthKit step count in SwiftUI — https://www.createwithswift.com/reading-data-from-healthkit-in-a-swiftui-app/
- Bottom sheet with presentationDetents — https://sarunw.com/posts/swiftui-bottom-sheet/
