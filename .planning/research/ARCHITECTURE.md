# Architecture Patterns — Nomad iOS Travel App

**Domain:** Native iOS travel logging app (SwiftUI + MapKit + Firebase)
**Researched:** 2026-04-03
**Overall confidence:** MEDIUM-HIGH

---

## Recommended Architecture

### Pattern: MVVM + Clean Architecture layers + Coordinator navigation

**Rationale:** Pure MVVM works for simple screens but breaks down under Nomad's complexity
(persistent globe state, stacked sheets, background location, offline sync). Pure TCA adds
significant boilerplate and steep learning curve with no concrete benefit for a solo/small-team
project at v1. The winning pattern seen in production travel/location apps is:

- **Clean Architecture layering** (Domain / Data / Presentation) for separation of concerns
- **MVVM at the view layer** with `@Observable` (iOS 17+) for efficient re-renders
- **Coordinator / Router pattern** for navigation between the persistent globe and all sheet stacks
- **Service singletons** for cross-cutting infrastructure (LocationService, FirebaseService, HealthKitService, PhotosService)

This hybrid is the "preferred choice for large-scale applications where long-term maintainability,
scalability, and testability are paramount" per current iOS architecture consensus (2025-2026).

---

## Layer Map

```
┌─────────────────────────────────────────────────────────────┐
│  PRESENTATION LAYER (SwiftUI Views + @Observable ViewModels) │
│                                                             │
│  GlobeView  ProfileSheetView  TripDetailView  PassportView  │
│      │             │               │               │        │
│  GlobeVM    ProfileVM         TripDetailVM    PassportVM    │
└──────────────────────────┬──────────────────────────────────┘
                           │  calls use-cases / services
┌──────────────────────────▼──────────────────────────────────┐
│  DOMAIN LAYER (Use Cases — pure Swift, no framework imports) │
│                                                             │
│  StartTripUseCase   DetectTravelUseCase   FetchTripsUseCase │
│  ImportPhotosUseCase  ComputeArchetypeUseCase  SyncUseCase  │
└──────────────────────────┬──────────────────────────────────┘
                           │  via protocol interfaces
┌──────────────────────────▼──────────────────────────────────┐
│  DATA LAYER (Repositories + Services)                        │
│                                                             │
│  TripRepository      LocationService      PhotosService     │
│  (Firestore + local) (CoreLocation)       (PhotoKit)        │
│  UserRepository      HealthKitService     StorageService    │
│  (Firestore + Auth)  (HealthKit)          (Firebase Storage)│
└─────────────────────────────────────────────────────────────┘
```

---

## Component Boundaries

| Component | Responsibility | Communicates With |
|-----------|---------------|-------------------|
| `AppCoordinator` | Root navigation state machine; controls which sheets are open | All ViewModels via Router |
| `GlobeView` + `GlobeViewModel` | Persistent base: renders MapKit globe, country polygons, trip pins; owns `MapCamera` state | AppCoordinator, TripRepository |
| `ProfileSheetView` + `ProfileViewModel` | First-level bottom sheet: trip list, "+" button, profile access | AppCoordinator, TripRepository |
| `TripDetailView` + `TripDetailViewModel` | Second-level bottom sheet: route map, place list, photo gallery | TripRepository, PhotosService |
| `PassportView` + `PassportViewModel` | Full-screen modal: stats, archetype, shareable card | UserRepository, TripRepository |
| `LocationService` | Singleton: manages CLLocationManager lifecycle, publishes location events, handles background continuation | TripRepository, DetectTravelUseCase |
| `TripRepository` | Read/write trips from Firestore; mirrors active trip to SwiftData for offline/performance | Firestore SDK, SwiftData |
| `PhotosService` | Queries PHAssets by date window + geo-bounding-box; returns matched assets | PhotoKit |
| `HealthKitService` | Queries step count for a date range | HealthKit |
| `RouteProcessor` | Takes raw CLLocation array, simplifies with Ramer-Douglas-Peucker, produces `[CLLocationCoordinate2D]` for MapKit | LocationService, TripRepository |

---

## Data Flow

### Active Trip Recording

```
CLLocationManager (foreground + background)
    │  publishes CLLocation every N meters (configurable accuracy)
    ▼
LocationService (Actor — thread-safe)
    │  buffers coordinates in memory; periodically flushes to SwiftData
    ▼
SwiftData (local — RoutePoint cache)
    │  on trip end, RouteProcessor simplifies points
    ▼
TripRepository.save(trip:)
    │  writes Trip document + subcollections to Firestore
    ▼
Firestore (source of truth)
```

### Globe Rendering

```
Firestore (trips collection for current user)
    │  snapshot listener on app foreground
    ▼
TripRepository (decodes Trip models)
    │
    ├─ visited country codes → GlobeViewModel
    │       │  renders MKPolygon overlays for each visited country
    │       ▼
    │   MapKit (custom MKPolygonRenderer with glow fill)
    │
    └─ trip pinpoints → GlobeViewModel
            │  renders MKAnnotation per trip
            ▼
        MapKit
```

### Photo Matching

```
User opens Trip Detail panel
    │
    ▼
PhotosService.fetchAssets(
    startDate: trip.startDate,
    endDate:   trip.endDate,
    boundingBox: trip.boundingBox   // derived from route points
)
    │  PHFetchOptions with NSPredicate on creationDate
    │  asset.location checked against bounding box client-side
    ▼
[PHAsset] returned — thumbnails rendered lazily in gallery
```

---

## Navigation Architecture

### The Persistent Globe Problem

SwiftUI's standard NavigationStack replaces the base view on push — incompatible with a globe
that must always be visible beneath all sheets. The correct pattern is a **layered sheet stack
anchored to a persistent root view**, not a navigation stack.

### Recommended Pattern: Observable Router with Two Sheet Slots

```swift
@Observable
final class AppRouter {
    var profileSheet: ProfileRoute?   // first sheet layer
    var detailSheet:  DetailRoute?    // second sheet, nested inside first
    var isPassportPresented: Bool = false
}
```

The root `ContentView` owns the globe and attaches both `.sheet` modifiers:

```swift
ContentView
└── GlobeView                         // always rendered
    └── .sheet(item: router.profileSheet)
            └── ProfileSheetView
                └── .sheet(item: router.detailSheet)
                        └── TripDetailView
```

`AppRouter` is injected via `@Environment` so any view can call `router.profileSheet = .tripList`
without knowing what else is on screen. This is the pattern described by [Martin's Tech Journal](https://blog.martinp7r.com/posts/decoupled-stacked-sheet-navigation-with-multiple-modals-in-swiftui/).

**ARCHITECTURAL RISK — HIGH:** SwiftUI enforces a one-active-sheet-per-view limit. Presenting
a sheet from inside a sheet is allowed but requires nesting the second `.sheet` modifier *inside
the content of the first sheet*. Failing to do this correctly causes the second sheet to silently
fail to present or dismiss the first sheet unexpectedly. Test this interaction before building any
feature that depends on it.

### Globe → Map Transition

The zoom from globe to country is a `MapCamera` animation, not a navigation push. `GlobeViewModel`
owns `@Observable var cameraPosition: MapCameraPosition` and updates it on country tap. MapKit
handles the animated camera fly-in. No sheet or navigation action is required for this transition.

---

## Firestore Data Model

### Design Principle
Design for read patterns, not write patterns. The most frequent read is: "give me all trips for
this user, with their route previews and stats, to render the globe and profile sheet." This
drives a document-per-trip model with denormalized summary fields at the trip level.

### Collection Structure

```
users/
  {uid}/
    handle: String
    homeCity: GeoPoint
    discoverScope: "everywhere" | "away_only"
    photoURL: String
    createdAt: Timestamp
    visitedCountryCodes: [String]   // denormalized — updated on each trip save

trips/
  {tripId}/
    userId: String                  // for security rules + friend queries (v2)
    title: String
    startDate: Timestamp
    endDate: Timestamp
    country: String
    city: String
    boundingBox: { ne: GeoPoint, sw: GeoPoint }
    totalSteps: Int
    totalDistanceMeters: Double
    coverPhotoURL: String?          // Firebase Storage URL
    placeCounts: { "restaurant": 3, "museum": 1 }   // denormalized for archetype
    routePreview: [GeoPoint]        // SIMPLIFIED ~50 points for globe pin preview
    createdAt: Timestamp
    updatedAt: Timestamp

    routePoints/                    // subcollection — full fidelity GPS trace
      {pointId}/
        coordinate: GeoPoint
        timestamp: Timestamp
        accuracy: Double

    places/                         // subcollection
      {placeId}/
        name: String
        category: String            // "restaurant" | "museum" | "park" | etc.
        coordinate: GeoPoint
        visitedAt: Timestamp
        durationMinutes: Int?

    dayLogs/                        // subcollection — one per calendar day in trip
      {dayId}/
        date: Timestamp
        steps: Int
        distanceMeters: Double
        placeIds: [String]          // references into places subcollection
```

### Key Design Decisions

**`routePreview` at trip level (denormalized):** The globe needs to render route previews for
all trips without fetching thousands of GPS points. Store ~50 simplified points at the trip
document level. This costs a few extra bytes per trip write but eliminates a subcollection query
on every globe load. HIGH confidence this is correct.

**`visitedCountryCodes` at user level (denormalized):** The globe highlight layer needs country
codes on app launch. A query across all trips to derive this list would be expensive. Maintain
a denormalized array on the user document, updated atomically with each trip save.

**`placeCounts` at trip level (denormalized):** Archetype computation needs aggregated place
type counts. Store them at the trip level so Passport stats can be computed with a single
trips collection query rather than fanning out into every places subcollection.

**Subcollections for `routePoints` and `places`:** These can have unbounded cardinality. Never
embed them in the trip document (Firestore's 1 MB document limit would be hit on long trips).

**ARCHITECTURAL RISK — MEDIUM:** Firestore does not support geo-range queries natively. Bounding
box queries require composite indexes on latitude + longitude, which Firestore does not support
directly. For v1, fetch all trips for the user (typically < 100 documents) and filter the bounding
box client-side. For v2 social features, evaluate Firestore's `GeoPoint` + Geohash approach or
consider a specialized geo-query solution.

---

## Background Location Architecture

### Mode Decision: Standard Location with Background Mode Enabled

**Do NOT use Significant Location Change as the primary recording mechanism.**
Significant Location Change fires at ~500m cell tower transitions — that is trip *detection*
granularity, not trip *recording* granularity. For a Strava-style GPS trace you need continuous
standard location updates.

**Architecture:**

```
Info.plist:
  UIBackgroundModes: ["location"]
  NSLocationAlwaysAndWhenInUseUsageDescription
  NSLocationAlwaysUsageDescription

CLLocationManager configuration (active trip):
  desiredAccuracy = kCLLocationAccuracyNearestTenMeters   // not Best — unnecessary battery drain
  distanceFilter  = 10.0                                  // meters — avoid point spam on foot
  allowsBackgroundLocationUpdates = true
  pausesLocationUpdatesAutomatically = false              // user controls trip end explicitly

CLLocationManager configuration (idle / detecting):
  Uses CLVisit monitoring — startMonitoringVisits()
  Uses Significant Location Change — startMonitoringSignificantLocationChanges()
  Both together give arrival/departure events that trigger the "you seem to be traveling" notification
```

### Two-Phase Location Strategy

**Phase 1 — Passive detection (no active trip):**
- `CLVisit` monitoring: fires when user arrives at or departs a location Apple considers
  noteworthy. Most battery-efficient detection primitive. Use as the primary trip detection signal.
- Significant location change: backup signal for coarse movement detection.
- Both survive app suspension and can relaunch the app to deliver their callbacks.
- On detection: evaluate against `discoverScope` (home city exclusion). If travel detected,
  send local notification: "Looks like you're traveling — start logging?"

**Phase 2 — Active recording (trip in progress):**
- Switch to standard location updates at 10m accuracy with 10m distance filter.
- `allowsBackgroundLocationUpdates = true` keeps the stream alive when the app is backgrounded.
- App must keep at least one active `CLLocationManager` with background location enabled or iOS
  will pause updates. Display the blue location pill in the status bar — this is expected and
  reassures users the app is tracking.
- On trip end (user taps stop or inactivity timeout): switch back to Phase 1 mode immediately.

**ARCHITECTURAL RISK — HIGH:** App Store review scrutinizes `UIBackgroundModes: location`
aggressively. The app must justify continuous background location in the usage description.
"Recording your trip route" is a valid justification. Do not enable this mode until the trip
logging feature is live and reviewable. Avoid running background location when no trip is active.

### What Survives App Suspension

| Mechanism | Survives Suspension | Relaunches App | Notes |
|-----------|--------------------|--------------------|-------|
| Standard location (background mode) | YES | YES | Requires `allowsBackgroundLocationUpdates = true` |
| CLVisit monitoring | YES | YES | Most reliable for trip detection |
| Significant location change | YES | YES | ~500m granularity |
| BGTaskScheduler | YES (scheduled) | YES | Use for syncing, not location |
| In-memory location buffer | NO | — | Flush to SwiftData regularly |

---

## Offline Support

### What to Cache (SwiftData) vs. Always Fetch (Firestore)

**Cache in SwiftData (local persistence):**

| Data | Reason |
|------|--------|
| Active trip route points (in-progress) | Firestore writes cost money and latency; buffer locally, flush on trip end |
| Last 20 trips (metadata + routePreview) | Profile sheet and globe must load instantly without network |
| User profile + visitedCountryCodes | Globe country highlighting must work offline |
| Pending Firestore writes (trip saves) | If app kills mid-trip, the data must survive |

**Always fetch from Firestore (no local cache needed):**

| Data | Reason |
|------|--------|
| Full GPS trace subcollection (past trips) | Only needed when user opens a trip detail; rare; 100 MB Firestore cache covers it |
| Places subcollection | Same — deep detail, fetched on demand |
| HealthKit step data | HealthKit is the source of truth; always query live |
| Photos (PHAssets) | Photos library is device-local; no caching needed |

**Firestore offline persistence:** Enable disk persistence with a 100 MB cache (the default).
This covers the gap for users who open old trip details while offline. The Firestore SDK handles
cache invalidation automatically.

```swift
// AppDelegate / app init
let settings = FirestoreSettings()
settings.isPersistenceEnabled = true
settings.cacheSizeBytes = FirestoreSettings.CACHE_SIZE_UNLIMITED
Firestore.firestore().settings = settings
```

**ARCHITECTURAL RISK — MEDIUM:** SwiftData has known issues with Firestore because `@Model`
classes use property wrappers that conflict with how Firestore's Codable decoding works. Keep
SwiftData models as mirror types (simple structs converted to `@Model`) — never share the same
model type between SwiftData and Firestore. Maintain explicit mapping functions between them.

---

## Photo Import Architecture

### Query Strategy

PhotoKit does not support a bounding-box geo-query natively. The approach:

1. Fetch all assets in the trip's date window using `PHFetchOptions` with an `NSPredicate`
   on `creationDate`:

   ```swift
   let predicate = NSPredicate(
       format: "creationDate >= %@ AND creationDate <= %@",
       trip.startDate as CVarArg,
       trip.endDate as CVarArg
   )
   ```

2. Iterate the result set and check `asset.location?.coordinate` against the trip bounding box
   (or a distance threshold from any route point). This is O(n) over the date-window result,
   which is typically small (< 200 photos per day of travel).

3. Return matched `PHAsset` objects. Thumbnails are loaded lazily via `PHImageManager`
   with `.opportunistic` delivery mode for smooth gallery scrolling.

**Important caveat:** `asset.location` is nil for photos shared from iCloud shared albums or
airdropped without metadata. Accept this gracefully — fall back to date-only matching for
assets without location.

**Performance note:** Never call `PHImageManager.requestImage` synchronously on the main thread.
Use async/await wrapper or a dedicated background queue. Gallery scroll performance depends on this.

**Privacy:** `NSPhotoLibraryUsageDescription` must explain the specific value: "Nomad uses your
photos to automatically populate trip galleries with pictures taken during your travels." Vague
descriptions cause App Store rejections.

---

## MapKit Performance

### Rendering GPS Traces with Thousands of Points

Raw GPS traces at 10m resolution for a full day of travel can have 5,000–15,000 points.
Passing these directly to `MKPolyline` causes rendering stutter, especially during map zoom/pan.

**Solution: Multi-resolution simplification pipeline**

```
Raw CLLocation[] (5,000–15,000 points)
    │
    ▼ RouteProcessor (background actor)
    │  Ramer-Douglas-Peucker, epsilon = 5m
    ▼
Simplified [CLLocationCoordinate2D] (~200–500 points) — store in Firestore routePoints subcollection
    │
    ├─ Full detail route: used in TripDetailView map (200–500 points — fine for single trip)
    │
    └─ Preview route (further simplify to ~50 points) — stored at trip document level for globe pins
```

Use [SwiftSimplify](https://github.com/malcommac/SwiftSimplify) or
[Simplify-Swift](https://github.com/tomislav/Simplify-Swift) — both are Swift ports of the
Ramer-Douglas-Peucker algorithm with acceptable performance (O(n log n) best case).

Run simplification on a background `Actor` or `Task.detached` before storing to Firestore.
Never block the main thread with this computation.

**ARCHITECTURAL RISK — MEDIUM:** MapKit in SwiftUI has documented performance issues with
> ~10 custom annotations visible simultaneously. Use clustering (`MKClusterAnnotation`) for
the globe pin layer when many trips exist in a country region. Country polygon overlays (MKPolygon
for visited countries) should be added once at app launch and not re-added on every view update —
MapKit forces full re-render on bulk overlay removal/re-addition.

### Country Polygon Highlighting

1. Bundle a world GeoJSON file (natural-earth or similar — ~800 KB simplified) with the app.
2. On app launch, decode with `MKGeoJSONDecoder` and pre-build `MKMultiPolygon` per country code.
3. Store in a `[String: MKMultiPolygon]` dictionary keyed by ISO 3166-1 alpha-2 code.
4. When `visitedCountryCodes` loads, call `mapView.addOverlays(visitedPolygons)` once.
5. `MKPolygonRenderer` with fill color + alpha creates the glow effect.

**Do not use SwiftUI `MapPolygon`** for this use case. The SwiftUI MapKit overlay API rebuilds
renderers on every SwiftUI state change. Use `UIViewRepresentable` wrapping `MKMapView` for the
globe so you have direct control over overlay lifecycle.

---

## State Management

### @Observable vs ObservableObject

Use `@Observable` (iOS 17+) throughout. Key advantages for this app:

- Views only re-render when the specific properties they *read* change — critical for `GlobeViewModel`
  which holds both camera state and overlay state; you don't want polygon updates triggering
  camera-related re-renders.
- No `@Published` annotations needed — all stored properties are implicitly observable.
- Works with `@State` instead of `@StateObject` — simpler initialization.

Minimum deployment target must be iOS 17 to use `@Observable`. Given the MapKit globe API
improvements in iOS 17, this is a reasonable floor.

### Global State: AppRouter + AppStore

```swift
@Observable final class AppRouter {
    var profileSheet: ProfileRoute?
    var detailSheet: DetailRoute?
    var isPassportPresented: Bool = false
    var activeTrip: Trip? = nil       // non-nil when recording
}

@Observable final class AppStore {
    var currentUser: UserProfile?
    var visitedCountryCodes: Set<String> = []
    var recentTrips: [Trip] = []      // last 20, cached from SwiftData
    var isOffline: Bool = false
}
```

Both injected at the root view via `.environment(appRouter)` and `.environment(appStore)`.
ViewModels access them as constructor arguments — never access global singletons directly in views.

---

## Suggested Build Order

This ordering minimizes architectural risk by establishing the riskiest components first.

### Phase 1: Core Infrastructure (risk reduction)
**Goal:** Prove the globe + persistent sheet stack works before any feature logic.

1. `AppRouter` + `ContentView` with globe as persistent root and two sheet slots wired up.
   Test: can you open profile sheet, open trip detail from inside it, dismiss both in order?
2. `UIViewRepresentable` MapKit globe view with `MKMapCamera` at globe altitude.
   Test: camera animations, tap gesture passthrough, zoom to country.
3. GeoJSON country polygon loading + `MKPolygonRenderer` with fill color.
   Test: add 5 arbitrary countries, verify overlay renders without stutter.
4. Firebase Auth + Firestore connection. Basic user document read/write.

### Phase 2: Location Pipeline
**Goal:** Establish the location data pipeline end-to-end (even with a dummy UI).

5. `LocationService` with both Phase 1 (CLVisit + significant change) and Phase 2 (standard)
   modes. Background location entitlement + Info.plist entries.
6. SwiftData schema for `RoutePointCache` and `TripDraft`.
7. `RouteProcessor` with Ramer-Douglas-Peucker simplification on a background actor.
8. Firestore write of a completed trip (trip document + routePoints subcollection).

### Phase 3: Core Features (globe → trip → detail)
**Goal:** The primary user journey works end to end.

9. Trip list in profile sheet reading from Firestore/SwiftData cache.
10. Globe pin annotations for each trip; tap → open trip detail sheet.
11. Trip detail map with simplified route polyline.
12. PhotosService: fetch and display matched PHAssets in trip gallery.
13. HealthKit step query for a trip date range.

### Phase 4: Trip Detection + Recording UX
**Goal:** Hybrid manual/auto detection works reliably.

14. CLVisit detection → local notification prompt.
15. Manual trip start/stop UI in profile sheet.
16. Active trip recording indicator (blue location pill, in-app status).
17. Trip end flow: route save, photo match, step query, Firestore write.

### Phase 5: Passport + Archetype
**Goal:** Stats and identity layer complete.

18. Traveler Passport view with world map + stats.
19. Archetype computation from denormalized `placeCounts`.
20. Share card export (UIGraphicsImageRenderer snapshot of PassportView).

---

## Architectural Risk Summary

| Risk | Severity | Area | Mitigation |
|------|----------|------|------------|
| Stacked sheets second-slot failure | HIGH | Navigation | Prototype this interaction in Phase 1 before any feature depends on it |
| App Store rejection for background location | HIGH | CoreLocation | Only enable `UIBackgroundModes: location` when trip recording is the explicit, justified use case |
| MapKit SwiftUI overlay rebuild on state change | HIGH | MapKit | Use `UIViewRepresentable` MKMapView for the globe, not SwiftUI `Map` with `MapPolygon` |
| Firestore geo-query limitation | MEDIUM | Data model | Client-side bounding box filter is fine for v1 (< 100 trips per user); revisit at v2 social scale |
| SwiftData + Firestore model conflict | MEDIUM | Offline | Use separate model types; never share `@Model` with Firestore Codable path |
| GPS trace rendering performance (10k+ points) | MEDIUM | MapKit | Simplify in RouteProcessor before any MapKit call; test with 20+ long trips on device (not simulator) |
| PHAsset.location nil for shared photos | LOW | PhotoKit | Graceful fallback to date-only matching; document this limitation |
| Battery drain during active recording | LOW | CoreLocation | 10m accuracy + 10m distance filter; switch back to CLVisit mode when trip ends |

---

## Sources

- [Modern iOS App Architecture in 2025 — Medium](https://medium.com/@csmax/the-ultimate-guide-to-modern-ios-architecture-in-2025-9f0d5fdc892f) — MEDIUM confidence (secondary source)
- [Modern iOS Architecture 2026: MVVM vs Clean vs TCA — 7Span](https://7span.com/blog/mvvm-vs-clean-architecture-vs-tca) — MEDIUM confidence
- [Decoupled Stacked Sheet Navigation — Martin's Tech Journal](https://blog.martinp7r.com/posts/decoupled-stacked-sheet-navigation-with-multiple-modals-in-swiftui/) — HIGH confidence (direct implementation pattern)
- [Optimizing iOS Location Services — Rangle.io](https://rangle.io/blog/optimizing-ios-location-services) — HIGH confidence (measurement-based analysis)
- [Handling Location Updates in the Background — Apple Developer Documentation](https://developer.apple.com/documentation/corelocation/handling-location-updates-in-the-background) — HIGH confidence (official)
- [CLVisit — Apple Developer Documentation](https://developer.apple.com/documentation/corelocation/clvisit) — HIGH confidence (official)
- [Access data offline — Firebase Documentation](https://firebase.google.com/docs/firestore/manage-data/enable-offline) — HIGH confidence (official)
- [PHAsset location property — Apple Developer Documentation](https://developer.apple.com/documentation/photokit/phasset/1624788-location) — HIGH confidence (official)
- [SwiftSimplify — GitHub](https://github.com/malcommac/SwiftSimplify) — HIGH confidence (active library)
- [Simplify-Swift — GitHub](https://github.com/tomislav/Simplify-Swift) — HIGH confidence (active library)
- [MapKit for SwiftUI WWDC23 — Apple Developer](https://developer.apple.com/videos/play/wwdc2023/10043/) — HIGH confidence (official)
- [@Observable macro performance — Antoine van der Lee](https://www.avanderlee.com/swiftui/observable-macro-performance-increase-observableobject/) — HIGH confidence (verified against official migration guide)
- [Migrating to @Observable — Apple Developer Documentation](https://developer.apple.com/documentation/SwiftUI/Migrating-from-the-observable-object-protocol-to-the-observable-macro) — HIGH confidence (official)
- [MapKit case study — GitHub tadelv/mapkit-swiftui-performance](https://github.com/tadelv/mapkit-swiftui-performance) — MEDIUM confidence (community research)
- [Significant Location Change — Swiftfy/Medium](https://medium.com/swiftfy/understanding-significant-location-in-ios-a-developers-guide-463162753a10) — MEDIUM confidence (secondary source)
- [MapKit Overlays in SwiftUI — createwithswift.com](https://www.createwithswift.com/using-mappolygon-overlays-in-mapkit-with-swiftui/) — MEDIUM confidence (community tutorial)
- [Energy Efficiency Guide for iOS — Apple Archive](https://developer.apple.com/library/archive/documentation/Performance/Conceptual/EnergyGuide-iOS/LocationBestPractices.html) — HIGH confidence (official, though archived)
