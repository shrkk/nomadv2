# Phase 2: Data & Auth Foundation - Research

**Researched:** 2026-04-05
**Domain:** Firebase Auth / iOS Core Location / SwiftData / MapKit POI / Firestore
**Confidence:** HIGH (core stack), MEDIUM (background GPS pitfalls), HIGH (Firestore schema)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Onboarding Flow Structure**
- D-01: Full-screen paged flow with progress indicator dots. One screen per step — no scrollable single page, no bottom sheet over globe. Clean, one-thing-at-a-time.
- D-02: Welcome screen first, before signup form: globe (or hero globe visual) as background, Playfair Display tagline, amber "Get started" CTA. Then email/password form on next screen.
- D-03: Onboarding step order: Welcome → Sign Up (email/password) → Handle → Location permission → Photos permission → Discovery scope → Home city confirm → Globe

**Handle Validation**
- D-04: Live, debounced Firestore uniqueness check as the user types — 500ms debounce. Inline feedback: green checkmark (available) or red "already taken" under the field. No surprises at submit.

**Permissions Screens**
- D-05: Each permission gets a custom pre-prompt explanation screen before the native iOS dialog fires. Two separate screens, two native dialogs.

**Discovery Scope Screen**
- D-06: Two large tappable option cards. Each card has: an icon, a label ("Everywhere" / "Away from home only"), and a one-line description. Full-width layout. No toggle, no segmented control.

**Home City Setup**
- D-07: Auto-detect from current location via CLGeocoder reverse-geocode to city name. Show the detected city for user confirmation ("Your home city: London — is this right?"). User can edit if wrong (text field opens). This happens as the last onboarding step after discovery scope.
- D-08: 50km geofence radius registered via CLLocationManager.startMonitoring(for: CLCircularRegion). Fixed — not user-adjustable.

**Auth State Management**
- D-09: `@Observable AuthManager` class (not struct — Firebase listener must persist). Listens on `Auth.auth().addStateDidChangeListener`. Injected as `@Environment(\.authManager)` or `@EnvironmentObject`. Drives a top-level `@ViewBuilder` switch in ContentView: `.unauthenticated` → OnboardingView, `.authenticated(user)` → GlobeView, `.loading` → stays on launch screen until Firebase resolves.
- D-10: No @AppStorage token storage — rely entirely on Firebase's own keychain-backed persistence (`Auth.auth().currentUser`). Firebase SDK handles session persistence across restarts.

**Launch Transition**
- D-11: For authenticated returning users, globe appears directly — no splash screen, no loading overlay. Firebase Auth resolves silently in background. Globe is the first visual.

**Firestore Schema**
- D-12: Trips live in `users/{uid}/trips/{tripId}` subcollection. Security rules: authenticated user can read/write only `users/{their uid}/**`.
- D-13: Full GPS trace stored in `users/{uid}/trips/{tripId}/routePoints/{pointId}` subcollection. Written in batches from SwiftData after trip ends. Not stored as an array on the trip doc (1MB Firestore limit).
- D-14: Trip document denormalized fields: `routePreview: [[Double]]`, `visitedCountryCodes: [String]`, `placeCounts: [String: Int]`, `cityName: String`, `startDate/endDate: Timestamp`, `stepCount: Int`, `distanceMeters: Double`, `userId: String`.

**User Document**
- D-15: `users/{uid}` document fields: `handle`, `email`, `homeCityName`, `homeCityLatitude`, `homeCityLongitude`, `discoveryScope`, `geofenceRadius`, `createdAt`, `onboardingComplete`.

**SwiftData Local Model**
- D-16: `RoutePoint` SwiftData model: `tripId`, `latitude`, `longitude`, `timestamp`, `accuracy`, `altitude`, `isSynced`.

### Claude's Discretion
- Exact onboarding screen animation/transition style (slide or fade between pages)
- Progress dots visual style (filled circles, thin bars, etc.)
- Welcome screen tagline copy
- Location pre-prompt and Photos pre-prompt exact copy
- SwiftData model for Trip entity (fields beyond RoutePoint)
- Firestore batch write size for routePoints (can decide 400 or 500 per batch)
- Firebase security rules exact syntax
- RDP simplification epsilon values (per REQUIREMENTS.md: ~500pt detail, ~50pt preview)

### Deferred Ideas (OUT OF SCOPE)
- Background recording UX (active trip indicator on globe, force-quit behavior) — Phase 3 UI concern once the data layer exists.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| AUTH-01 | Sign up and sign in with email/password via Firebase Auth | Firebase Auth SDK — `createUser(withEmail:password:)` + `signIn(withEmail:password:)` patterns verified |
| AUTH-02 | Session persists across app restarts | Firebase iOS SDK persists auth state in keychain automatically; `Auth.auth().currentUser` non-nil on relaunch |
| AUTH-03 | User sets unique handle validated against Firestore | Separate `usernames/{handle}` collection pattern enables doc-ID uniqueness; debounce via Task + try await |
| AUTH-04 | Always-on location permission granted during onboarding | `requestAlwaysAuthorization()` after `NSLocationAlwaysAndWhenInUseUsageDescription` plist key is set |
| AUTH-05 | Photos library access granted during onboarding | `PHPhotoLibrary.requestAuthorization(for: .readWrite)` on the pre-prompt screen |
| AUTH-06 | Discovery scope chosen at onboarding | UserDefaults or Firestore user doc `discoveryScope` field; no system API needed |
| AUTH-07 | Home city geofence registered at onboarding | `CLLocationManager.startMonitoring(for: CLCircularRegion)` with 50km radius after CLGeocoder reverse-geocode |
| LOC-01 | Background GPS with correct iOS 16.4+ accuracy/filter settings | `distanceFilter = kCLDistanceFilterNone`, `desiredAccuracy = kCLLocationAccuracyBest`, `allowsBackgroundLocationUpdates = true` |
| LOC-02 | CLBackgroundActivitySession keeps location alive when backgrounded | Create and retain `CLBackgroundActivitySession` instance; pair with `CLLocationUpdate.liveUpdates()` async stream |
| LOC-03 | Route points buffered in SwiftData before Firestore sync | `@Model RoutePoint` with `isSynced: Bool`; query `isSynced == false` to find pending batch writes |
| LOC-04 | Ramer-Douglas-Peucker simplification on GPS traces | Pure Swift RDP implementation using perpendicular distance; epsilon ~10m for 500-pt detail, ~50m for 50-pt preview |
| LOC-05 | CLVisit monitoring detects home city departure, triggers prompt | `startMonitoringVisits()` + `locationManager(_:didVisit:)` combined with CLCircularRegion exit event |
| LOC-06 | Discovery scope enforced — home city geofence suppresses prompts | Check `discoveryScope == "awayOnly"` before sending UNUserNotification prompt on visit/geofence exit |
| PLACE-01 | Each stop categorized via MKLocalPointsOfInterestRequest | `MKLocalPointsOfInterestRequest(center:radius:)` + `MKLocalSearch`; returns `MKMapItem` with `.pointOfInterestCategory` |
| PLACE-02 | Categories mapped to 6 scoring dimensions | Static mapping dict from `MKPointOfInterestCategory` → `[Food, Culture, Nature, Nightlife, Wellness, Local]` |
| PLACE-03 | Category results cached by coordinate key | Dictionary keyed by `"\(lat_rounded),\(lon_rounded)"` (2 decimal places ≈ 1km grid cell) |
| PLACE-04 | placeCounts stored per trip in Firestore | Aggregated on trip end and written to `users/{uid}/trips/{tripId}.placeCounts` as `[String: Int]` |
</phase_requirements>

---

## Summary

Phase 2 delivers the entire data and identity layer that Phase 3's UI will read from. It breaks into four distinct technical domains:

**Firebase Auth + Onboarding** — Firebase 12.x (current: 12.11.0 via SPM) provides email/password auth with automatic keychain session persistence. The `@Observable AuthManager` pattern using `addStateDidChangeListener` is the standard approach and is compatible with Swift 6 when marked `@MainActor`. Handle uniqueness requires a dedicated `usernames/{handle}` Firestore collection (document IDs are the only guaranteed-unique Firestore values) — a simple `.getDocument()` tells you if a handle is taken.

**Background GPS Recording** — iOS 16.4 introduced a breaking change to background location: `distanceFilter` must be `kCLDistanceFilterNone` and `desiredAccuracy` must be ≤ 100m. Additionally, `CLBackgroundActivitySession` (iOS 17+) is the modern replacement for the old background-task approach. It must be created and retained for the duration of the recording session alongside `CLLocationUpdate.liveUpdates()`. The combination of both is what keeps GPS alive through a locked screen.

**Route Simplification + Firestore Write** — Ramer-Douglas-Peucker is a pure algorithm (no library needed) that reduces a GPS trace to a target point count via a single epsilon parameter. A two-pass approach yields the detail array (~500pt, epsilon ~10m) and the preview array (~50pt, epsilon ~50m). Firestore's 500-operation batch write limit means large route point sets must be chunked into multiple `WriteBatch` commits.

**Place Categorization** — `MKLocalPointsOfInterestRequest` returns `MKMapItem` objects with `.pointOfInterestCategory` populated. This is confirmed working (unlike `CLPlacemark` which returns nil). Apple provides ~40 categories. The 6-dimension mapping (Food, Culture, Nature, Nightlife, Wellness, Local) requires a static dictionary mapping each `MKPointOfInterestCategory` case.

**Primary recommendation:** Build and test background GPS on a physical device (not simulator) before writing any other pipeline code — if this doesn't work, nothing else in Phase 2 matters.

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| FirebaseAuth | 12.11.0 | Email/password auth, session persistence | Official Firebase SDK — already in project via SPM [VERIFIED: swiftpackageindex.com/firebase/firebase-ios-sdk] |
| FirebaseFirestore | 12.11.0 | User doc, trip doc, routePoints writes | Already in project; batch write API built-in [VERIFIED: project codebase] |
| SwiftData | iOS 17+ (stdlib) | Local RoutePoint buffer before sync | Apple-native, zero-dependency, @Model macro [ASSUMED] |
| CoreLocation | iOS 17+ (stdlib) | Background GPS, CLVisit, geofence, CLBackgroundActivitySession | Apple-native [VERIFIED: developer.apple.com] |
| MapKit | iOS 13+ (stdlib) | MKLocalPointsOfInterestRequest for POI categories | Apple-native; only MapKit returns non-nil categories [VERIFIED: REQUIREMENTS.md spike result] |
| UserNotifications | iOS 17+ (stdlib) | Local notification for CLVisit-based trip prompt | Apple-native [ASSUMED] |
| Photos | iOS 14+ (stdlib) | PHPhotoLibrary.requestAuthorization during onboarding | Apple-native [ASSUMED] |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| CLGeocoder | stdlib | Reverse-geocode current location to city name | Home city auto-detect at end of onboarding |
| UNUserNotificationCenter | stdlib | Schedule and deliver trip-start prompt | After CLVisit departure detection |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| SwiftData buffer | Core Data | SwiftData is simpler; Core Data only needed for iOS <17 targets (not our case) |
| CLBackgroundActivitySession | Old background task + CLLocationManager delegate | Old approach silently fails on iOS 16.4+ — CLBackgroundActivitySession is correct modern pattern |
| MKLocalPointsOfInterestRequest | CLPlacemark category lookup | CLPlacemark returns nil for category — confirmed invalid; MKLocalPointsOfInterestRequest is the only working approach |
| Firestore batch for routePoints | Firestore array on trip doc | Arrays hit 1MB document limit with large GPS traces; subcollection + batch is correct |

**Installation:** Firebase is already integrated via SPM. No new package dependencies needed for Phase 2. All other APIs (CoreLocation, MapKit, SwiftData, Photos, UserNotifications) are system frameworks.

**Version verification:** Firebase iOS SDK 12.11.0 is the current release as of 2026-04-05. [VERIFIED: swiftpackageindex.com/firebase/firebase-ios-sdk]

---

## Architecture Patterns

### Recommended Project Structure

```
Nomad/
├── Auth/
│   ├── AuthManager.swift           # @Observable @MainActor — owns Firebase listener
│   ├── UserService.swift           # handle uniqueness check, user doc write
│   └── OnboardingCoordinator.swift # step state machine
├── Onboarding/
│   ├── OnboardingView.swift        # TabView pager container
│   ├── WelcomeScreen.swift
│   ├── SignUpScreen.swift
│   ├── HandleScreen.swift
│   ├── LocationPermissionScreen.swift
│   ├── PhotosPermissionScreen.swift
│   ├── DiscoveryScopeScreen.swift
│   └── HomeCityScreen.swift
├── Location/
│   ├── LocationManager.swift       # CLLocationManager wrapper + CLBackgroundActivitySession
│   ├── VisitMonitor.swift          # CLVisit + geofence monitoring
│   └── RouteSimplifier.swift       # Ramer-Douglas-Peucker implementation
├── Data/
│   ├── Models/
│   │   ├── RoutePoint.swift        # @Model SwiftData
│   │   └── TripLocal.swift         # @Model SwiftData (local trip buffer)
│   ├── TripService.swift           # Firestore trip doc + routePoints batch write
│   └── PlaceCategoryService.swift  # MKLocalPointsOfInterestRequest + coordinate cache
└── Firebase/
    ├── FirebaseService.swift       # EXISTING — will be expanded/replaced
    └── FirestoreSchema.swift       # Firestore path constants (type-safe document paths)
```

---

### Pattern 1: AuthManager with @Observable + Firebase Auth Listener

**What:** `@Observable @MainActor class AuthManager` holds auth state and drives the root view switch.
**When to use:** Always — this is the single source of truth for auth state across the app.

```swift
// Source: Firebase Auth docs + Swift 6 @Observable pattern [CITED: firebase.google.com/docs/auth/ios/start]
import FirebaseAuth
import Observation

enum AuthState {
    case loading
    case unauthenticated
    case authenticated(User)
}

@Observable
@MainActor
final class AuthManager {
    var authState: AuthState = .loading
    private var listenerHandle: AuthStateDidChangeListenerHandle?

    init() {
        listenerHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                if let user {
                    self?.authState = .authenticated(user)
                } else {
                    self?.authState = .unauthenticated
                }
            }
        }
    }

    func signUp(email: String, password: String) async throws -> User {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        return result.user
    }

    func signIn(email: String, password: String) async throws {
        try await Auth.auth().signIn(withEmail: email, password: password)
    }

    func signOut() throws {
        try Auth.auth().signOut()
    }

    deinit {
        if let handle = listenerHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
}
```

Root view switch in NomadApp or ContentView:
```swift
// Source: D-09 (CONTEXT.md)
@main
struct NomadApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @State private var authManager = AuthManager()

    var body: some Scene {
        WindowGroup {
            switch authManager.authState {
            case .loading:
                Color.Nomad.globeBackground.ignoresSafeArea() // silent wait
            case .unauthenticated:
                OnboardingView()
            case .authenticated:
                GlobeView()
            }
        }
        .environment(authManager)
    }
}
```

---

### Pattern 2: Handle Uniqueness — Separate `usernames` Collection

**What:** Create a separate `usernames/{handle}` collection. Document presence = handle taken. Write the user doc and username doc atomically in one `WriteBatch`.
**When to use:** Any Firestore uniqueness constraint — document IDs are the only guaranteed-unique values in Firestore.

```swift
// Source: Firestore uniqueness pattern [CITED: firebase.google.com/docs/firestore/manage-data/transactions]
func isHandleAvailable(_ handle: String) async -> Bool {
    let doc = try? await Firestore.firestore()
        .collection("usernames")
        .document(handle.lowercased())
        .getDocument()
    return !(doc?.exists ?? false)
}

// Atomic write: user doc + username reservation
func createUserDocument(uid: String, handle: String, email: String) async throws {
    let db = Firestore.firestore()
    let batch = db.batch()
    
    let userRef = db.collection("users").document(uid)
    batch.setData([
        "handle": handle,
        "email": email,
        "createdAt": FieldValue.serverTimestamp(),
        "onboardingComplete": false
    ], forDocument: userRef)
    
    let usernameRef = db.collection("usernames").document(handle.lowercased())
    batch.setData(["uid": uid], forDocument: usernameRef)
    
    try await batch.commit()
}
```

Debounce in SwiftUI (500ms — D-04):
```swift
// Source: D-04 (CONTEXT.md) + Swift Concurrency pattern [ASSUMED]
.onChange(of: handleText) { _, newValue in
    debounceTask?.cancel()
    debounceTask = Task {
        try? await Task.sleep(for: .milliseconds(500))
        guard !Task.isCancelled else { return }
        handleAvailable = await userService.isHandleAvailable(newValue)
    }
}
```

---

### Pattern 3: Background GPS with CLBackgroundActivitySession (iOS 17+)

**What:** `CLBackgroundActivitySession` keeps your app in the foreground-equivalent state for location purposes. Must be retained for the session duration. Pairs with `CLLocationUpdate.liveUpdates()` async stream.
**When to use:** Any continuous background GPS recording that must survive a locked screen.

```swift
// Source: Apple Developer Forums + twocentstudios.com/2024/12/02/core-location-modern-api-tips/
// [CITED: developer.apple.com/documentation/corelocation/clbackgroundactivitysession-3mzv3]
import CoreLocation

@Observable
final class LocationManager {
    private var backgroundSession: CLBackgroundActivitySession?
    private var recordingTask: Task<Void, Never>?
    var isRecording = false

    func startRecording(tripId: String) {
        guard !isRecording else { return }
        isRecording = true
        backgroundSession = CLBackgroundActivitySession()  // retain this!

        recordingTask = Task {
            do {
                let updates = CLLocationUpdate.liveUpdates()
                for try await update in updates {
                    guard let location = update.location else { continue }
                    // Filter: only accept updates with horizontal accuracy < 50m
                    guard location.horizontalAccuracy < 50 else { continue }
                    await saveRoutePoint(location: location, tripId: tripId)
                }
            } catch {
                // Handle location error
            }
        }
    }

    func stopRecording() {
        recordingTask?.cancel()
        recordingTask = nil
        backgroundSession?.invalidate()
        backgroundSession = nil
        isRecording = false
    }
}
```

**Critical Info.plist keys required (MISSING from current project — must be added):**
```xml
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Nomad tracks your route in the background so your journey is captured even when your phone is locked.</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>Nomad uses your location to track trips and detect your home city.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Nomad matches photos from your library to trips by date and location.</string>
<key>UIBackgroundModes</key>
<array>
    <string>location</string>
</array>
```

**CLLocationManager configuration (must be set before startUpdatingLocation — for fallback/CLVisit path):**
```swift
// Source: cropsly.com/blog/location-updates-changes-in-ios-16-4/ [CITED]
manager.distanceFilter = kCLDistanceFilterNone   // required — any numeric value may cause suspension
manager.desiredAccuracy = kCLLocationAccuracyBest
manager.allowsBackgroundLocationUpdates = true
manager.showsBackgroundLocationIndicator = true  // shows blue status bar — makes background mode explicit to user
manager.pausesLocationUpdatesAutomatically = false
```

---

### Pattern 4: CLVisit + Geofence for Trip Auto-Detection

**What:** `startMonitoringVisits()` detects significant location events (arrivals/departures). Pair with `CLCircularRegion` monitoring for explicit home city geofence exit.
**When to use:** LOC-05 and LOC-06 — detect departure from home city to trigger trip notification.

```swift
// Source: Apple CoreLocation docs [ASSUMED — standard CLLocationManager delegate pattern]
func setupHomeCityGeofence(latitude: Double, longitude: Double, radius: Double = 50_000) {
    let center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    let region = CLCircularRegion(center: center, radius: radius, identifier: "homeCityGeofence")
    region.notifyOnEntry = false
    region.notifyOnExit = true  // only care about departures
    locationManager.startMonitoring(for: region)
    locationManager.startMonitoringVisits()
}

// Delegate method
func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
    guard region.identifier == "homeCityGeofence" else { return }
    // Check discovery scope before firing notification
    let scope = UserDefaults.standard.string(forKey: "discoveryScope") ?? "everywhere"
    if scope == "awayOnly" {
        sendTripStartNotification()
    } else if scope == "everywhere" {
        sendTripStartNotification()  // always prompt
    }
}
```

---

### Pattern 5: Ramer-Douglas-Peucker Route Simplification

**What:** Pure Swift implementation — no library needed. Takes an array of coordinates, returns a simplified array preserving shape within epsilon tolerance (in meters for GPS).
**When to use:** LOC-04 — after trip ends, before writing to Firestore.

```swift
// Source: Algorithm from Ramer (1972), Swift port pattern [CITED: gist.github.com/yageek/287843360aeaecdda14cb12f9fbb60dc]
// Adapted for CLLocationCoordinate2D

struct RouteSimplifier {
    // Returns simplified route. Call twice: epsilon=10 for ~500pt detail, epsilon=50 for ~50pt preview.
    static func simplify(_ points: [CLLocationCoordinate2D], epsilon: Double) -> [CLLocationCoordinate2D] {
        guard points.count > 2 else { return points }
        
        var maxDistance = 0.0
        var maxIndex = 0
        
        let firstPoint = points.first!
        let lastPoint = points.last!
        
        for i in 1..<points.count - 1 {
            let distance = perpendicularDistance(point: points[i], lineStart: firstPoint, lineEnd: lastPoint)
            if distance > maxDistance {
                maxDistance = distance
                maxIndex = i
            }
        }
        
        if maxDistance > epsilon {
            let left = simplify(Array(points[0...maxIndex]), epsilon: epsilon)
            let right = simplify(Array(points[maxIndex...]), epsilon: epsilon)
            return left.dropLast() + right
        } else {
            return [firstPoint, lastPoint]
        }
    }
    
    // Perpendicular distance in meters using Haversine approximation
    private static func perpendicularDistance(
        point: CLLocationCoordinate2D,
        lineStart: CLLocationCoordinate2D,
        lineEnd: CLLocationCoordinate2D
    ) -> Double {
        let pLoc = CLLocation(latitude: point.latitude, longitude: point.longitude)
        let startLoc = CLLocation(latitude: lineStart.latitude, longitude: lineStart.longitude)
        let endLoc = CLLocation(latitude: lineEnd.latitude, longitude: lineEnd.longitude)
        
        let lineLength = startLoc.distance(from: endLoc)
        guard lineLength > 0 else { return pLoc.distance(from: startLoc) }
        
        // Project point onto line segment
        let t = max(0, min(1, dotProduct(point, lineStart, lineEnd) / (lineLength * lineLength)))
        let projLat = lineStart.latitude + t * (lineEnd.latitude - lineStart.latitude)
        let projLon = lineStart.longitude + t * (lineEnd.longitude - lineStart.longitude)
        let projLoc = CLLocation(latitude: projLat, longitude: projLon)
        
        return pLoc.distance(from: projLoc)
    }
    
    private static func dotProduct(
        _ p: CLLocationCoordinate2D,
        _ lineStart: CLLocationCoordinate2D,
        _ lineEnd: CLLocationCoordinate2D
    ) -> Double {
        let dx = lineEnd.longitude - lineStart.longitude
        let dy = lineEnd.latitude - lineStart.latitude
        let px = p.longitude - lineStart.longitude
        let py = p.latitude - lineStart.latitude
        return px * dx + py * dy
    }
}

// Usage after trip ends:
let detailRoute = RouteSimplifier.simplify(rawCoordinates, epsilon: 10.0)   // ~200-500pt
let previewRoute = RouteSimplifier.simplify(rawCoordinates, epsilon: 50.0)  // ~50pt
```

---

### Pattern 6: MKLocalPointsOfInterestRequest + Category Mapping

**What:** Query nearby POIs using MapKit for a coordinate. Map returned categories to 6 scoring dimensions.
**When to use:** PLACE-01, PLACE-02 — after each stop during a trip.

```swift
// Source: Apple MapKit docs [CITED: developer.apple.com/documentation/mapkit/mklocalpointsofinterestrequest]
import MapKit

actor PlaceCategoryService {
    private var cache: [String: [String: Int]] = [:]  // coordinateKey → placeCounts
    
    func categorize(coordinate: CLLocationCoordinate2D) async throws -> [String: Int] {
        let key = coordinateKey(coordinate)
        if let cached = cache[key] { return cached }
        
        let region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 200,
            longitudinalMeters: 200
        )
        let request = MKLocalPointsOfInterestRequest(coordinateRegion: region)
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: mappedCategories)
        
        let search = MKLocalSearch(request: request)
        let response = try await search.start()
        
        var counts = emptyPlaceCounts()
        for item in response.mapItems {
            if let category = item.pointOfInterestCategory,
               let dimension = categoryToDimension[category] {
                counts[dimension, default: 0] += 1
            }
        }
        
        cache[key] = counts
        return counts
    }
    
    // Coordinate key: round to 2 decimal places ≈ 1.1km grid cell
    private func coordinateKey(_ coord: CLLocationCoordinate2D) -> String {
        let lat = (coord.latitude * 100).rounded() / 100
        let lon = (coord.longitude * 100).rounded() / 100
        return "\(lat),\(lon)"
    }
    
    private func emptyPlaceCounts() -> [String: Int] {
        ["Food": 0, "Culture": 0, "Nature": 0, "Nightlife": 0, "Wellness": 0, "Local": 0]
    }
}
```

---

### Pattern 7: Firestore routePoints Batch Write (500-op limit)

**What:** Split routePoints into chunks of ≤ 400 (safe margin below 500 limit) and commit each as a separate `WriteBatch`.
**When to use:** LOC-03, D-13 — after trip ends, when syncing SwiftData buffer to Firestore.

```swift
// Source: Firestore batch limit docs [CITED: firebase.google.com/docs/firestore/manage-data/transactions]
func syncRoutePoints(points: [RoutePoint], userId: String, tripId: String) async throws {
    let db = Firestore.firestore()
    let chunks = stride(from: 0, to: points.count, by: 400).map {
        Array(points[$0..<min($0 + 400, points.count)])
    }
    
    for chunk in chunks {
        let batch = db.batch()
        for point in chunk {
            let ref = db.collection("users").document(userId)
                .collection("trips").document(tripId)
                .collection("routePoints").document()
            batch.setData([
                "latitude": point.latitude,
                "longitude": point.longitude,
                "timestamp": Timestamp(date: point.timestamp),
                "accuracy": point.accuracy,
                "altitude": point.altitude
            ], forDocument: ref)
        }
        try await batch.commit()
    }
}
```

---

### Anti-Patterns to Avoid

- **Using distanceFilter > 0 or desiredAccuracy > kCLLocationAccuracyHundredMeters:** Background location silently stops on iOS 16.4+ with these settings. Must use `kCLDistanceFilterNone` and `kCLLocationAccuracyBest` or `kCLLocationAccuracyHundredMeters`. [CITED: cropsly.com/blog/location-updates-changes-in-ios-16-4/]
- **Not retaining CLBackgroundActivitySession:** If the session is released (e.g., a local variable goes out of scope), the blue indicator disappears and background updates stop. Keep it as a class property.
- **CLPlacemark for category lookup:** Returns nil for `.areasOfInterest` and `.pointOfInterestCategory` in most cases — this is why MKLocalPointsOfInterestRequest is required. [VERIFIED: STATE.md spike result]
- **Storing routePoints as an array field on the trip document:** Firestore document max size is 1MB. A 10-minute GPS trace at 1Hz = 600 points. At roughly 100 bytes each, that's fine — but longer trips break the limit. Use the subcollection pattern from D-13.
- **Checking handle uniqueness with a Firestore `where` query:** Firestore doesn't have unique constraints on fields. Document IDs are unique — create a `usernames/{handle}` collection and use `.getDocument()` instead of a query.
- **Starting CLLocationManager inside a view's onAppear:** The manager must live in a long-lived object (like `LocationManager`) that persists beyond view lifecycle. Views get recreated.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Auth state persistence across restarts | Custom keychain token storage | Firebase SDK built-in persistence | Firebase already stores the refresh token in the iOS keychain; `Auth.auth().currentUser` is non-nil after restart automatically |
| Uniqueness constraint on handle field | Firestore query + hope | Separate `usernames/{handle}` collection | Firestore has no server-side unique constraints on fields; document IDs are the only enforcement point |
| Background location survival | Manual background task with beginBackgroundTask | `CLBackgroundActivitySession` | Apple's dedicated API for exactly this use case; manual approach fails on iOS 16.4+ |
| GPS trace compression | Custom binary format | RDP algorithm + `[[Double]]` Firestore array | RDP is O(n log n), well-understood, and the output maps directly to Firestore's array type |
| POI category lookup | Geocoding address + string parsing | `MKLocalPointsOfInterestRequest` | Returns structured `MKPointOfInterestCategory` enum values; no string parsing |
| Rate limiting POI requests | Exponential backoff + retry queue | Coordinate-keyed cache (PLACE-03) | Cache eliminates repeat calls entirely; 2-decimal-place coordinate grid provides ~1km resolution |

**Key insight:** iOS already solves the hard problems in this phase (auth persistence, background GPS, POI lookup). The architecture task is wiring these Apple APIs correctly — not building custom infrastructure.

---

## MKPointOfInterestCategory → 6-Dimension Mapping

All confirmed Apple-documented categories as of iOS 13+ [VERIFIED: github.com/xybp888/iOS-SDKs MKPointOfInterestCategory.h]:

| MKPointOfInterestCategory | Nomad Dimension |
|---------------------------|-----------------|
| .restaurant | Food |
| .cafe | Food |
| .bakery | Food |
| .foodMarket | Food |
| .brewery | Food / Nightlife |
| .winery | Food |
| .nightlife | Nightlife |
| .movieTheater | Culture |
| .theater | Culture |
| .museum | Culture |
| .library | Culture |
| .university | Culture |
| .aquarium | Culture |
| .zoo | Culture |
| .amusementPark | Culture |
| .stadium | Culture |
| .park | Nature |
| .nationalPark | Nature |
| .beach | Nature |
| .campground | Nature |
| .hiking | Nature |
| .marina | Nature |
| .fitnessCenter | Wellness |
| .spa (if available) | Wellness |
| .hospital | Wellness |
| .pharmacy | Wellness |
| .store | Local |
| .bank | Local |
| .postOffice | Local |
| .publicTransport | Local |
| .school | Local |
| .hotel | Local |
| .gasStation | — (skip) |
| .parking | — (skip) |
| .atm | — (skip) |
| .airport | — (skip) |
| .carRental | — (skip) |
| .evCharger | — (skip) |
| .fireStation | — (skip) |
| .police | — (skip) |
| .restroom | — (skip) |
| .laundry | — (skip) |

**Note:** `.spa` does not appear in the iOS 13 header. It may have been added in a later iOS SDK. Map to Wellness if present; skip if the category is unrecognized. The mapping dictionary should use a `default: nil` pattern and silently skip unknown categories.

---

## Common Pitfalls

### Pitfall 1: iOS 16.4 Background Location Suspension
**What goes wrong:** Background GPS recording silently stops after the app is suspended — no crash, no error, just no more location updates.
**Why it happens:** iOS 16.4 introduced a change requiring `distanceFilter = kCLDistanceFilterNone` and `desiredAccuracy ≤ kCLLocationAccuracyHundredMeters`. Any other configuration causes silent suspension. [CITED: cropsly.com/blog/location-updates-changes-in-ios-16-4/]
**How to avoid:** Set `distanceFilter = kCLDistanceFilterNone` and `desiredAccuracy = kCLLocationAccuracyBest` on the `CLLocationManager` instance AND on the `CLLocationUpdate` stream. Set `allowsBackgroundLocationUpdates = true` and `pausesLocationUpdatesAutomatically = false`.
**Warning signs:** RoutePoint table in SwiftData stops accumulating during a locked-screen test. Check the background modes capability in Xcode project settings — it must have "Location updates" checked.

### Pitfall 2: CLBackgroundActivitySession Deallocation
**What goes wrong:** Background updates stop suddenly mid-recording. Blue location status bar disappears.
**Why it happens:** `CLBackgroundActivitySession` is reference-counted. If stored as a local variable or optional that gets niled out, the session ends automatically. [CITED: developer.apple.com/documentation/corelocation/clbackgroundactivitysession-3mzv3]
**How to avoid:** Store the session as a strong `var backgroundSession: CLBackgroundActivitySession?` on the `LocationManager` object (which itself must live in an app-level scope, not in a view). Only call `.invalidate()` when intentionally stopping.
**Warning signs:** Background recording works initially but stops unexpectedly.

### Pitfall 3: Firestore Security Rules in Test Mode
**What goes wrong:** App ships with Firestore open read/write rules (test mode from Phase 1 setup). Any unauthenticated user can read/write all user data.
**Why it happens:** Phase 1 used test mode rules as a spike shortcut (documented as temporary in `FirebaseService.swift`). Phase 2 must replace them.
**How to avoid:** Write and deploy production security rules as one of the first Phase 2 tasks — before any real user data is written.
**Required rules:**
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    match /usernames/{handle} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
  }
}
```

### Pitfall 4: Handle Race Condition
**What goes wrong:** Two users simultaneously check the same handle as available, both proceed to write. Both accounts get the same handle.
**Why it happens:** Check-then-write pattern has a TOCTOU (time-of-check/time-of-use) window.
**How to avoid:** The `usernames/{handle}` document write in the `WriteBatch` with a Firestore security rule `allow write: if !exists(...)` approach. In practice for v1 (single-user, low concurrency), the 500ms debounce + final check-before-write pattern is acceptable. A stricter solution uses a Cloud Function or Firestore security rule with `allow create: if !exists(/databases/$(database)/documents/usernames/$(handle))`.
**Warning signs:** Duplicate handles in production (rare in v1 low-traffic scenario).

### Pitfall 5: `Always` Location Permission Two-Step
**What goes wrong:** User is shown the native iOS prompt but only grants "When In Use" — background GPS never works.
**Why it happens:** iOS requires `requestWhenInUseAuthorization()` first. Then, only after the user has granted "When In Use", can you call `requestAlwaysAuthorization()` and present the "Always Allow" upgrade prompt. You cannot jump directly to Always.
**How to avoid:** The Location pre-prompt screen should call `requestWhenInUseAuthorization()`. After authorization is granted, immediately call `requestAlwaysAuthorization()` (iOS shows the upgrade prompt automatically if the user chose "While Using"). Both calls must come from the same `CLLocationManager` instance.
**Warning signs:** `authorizationStatus == .authorizedWhenInUse` rather than `.authorizedAlways` after onboarding — background GPS will not work.

### Pitfall 6: SwiftData ModelContainer Not Shared
**What goes wrong:** Two different parts of the app access different `ModelContext` instances, causing duplicate records or stale reads.
**Why it happens:** `ModelContainer` should be a singleton. Creating multiple containers for the same schema creates separate stores.
**How to avoid:** Create a single `ModelContainer` at the app level (in `NomadApp`) and pass it via `.modelContainer()` modifier. Use `@Environment(\.modelContext)` in views. The `LocationManager` background service should receive a `ModelContext` explicitly rather than creating its own.

### Pitfall 7: CLLocationUpdate on iOS 17 (Avoid — Use iOS 18+)
**What goes wrong:** `CLLocationUpdate.liveUpdates()` has known issues on iOS 17 with accuracy handling.
**Why it happens:** API was introduced in iOS 17 but had reliability issues on that version. [CITED: twocentstudios.com/2024/12/02/core-location-modern-api-tips/]
**How to avoid:** Target iOS 18+ for the `CLLocationUpdate` async stream API. Alternatively, use the traditional `CLLocationManager` delegate with `startUpdatingLocation()` for broader compatibility — the delegate approach works on iOS 16.4+ with the correct `distanceFilter`/`desiredAccuracy` settings.

---

## Code Examples

### CLGeocoder Async Reverse Geocode (Home City Detection)

```swift
// Source: Apple CLGeocoder docs [CITED: developer.apple.com/documentation/corelocation/clgeocoder]
func detectHomeCity(from location: CLLocation) async throws -> String {
    let geocoder = CLGeocoder()
    let placemarks = try await geocoder.reverseGeocodeLocation(location)
    guard let placemark = placemarks.first,
          let city = placemark.locality ?? placemark.administrativeArea else {
        throw LocationError.cityNotFound
    }
    return city
}
```

### SwiftData RoutePoint Model

```swift
// Source: D-16 (CONTEXT.md) + SwiftData @Model pattern [ASSUMED — stdlib]
import SwiftData

@Model
final class RoutePoint {
    var tripId: String
    var latitude: Double
    var longitude: Double
    var timestamp: Date
    var accuracy: Double
    var altitude: Double
    var isSynced: Bool

    init(tripId: String, location: CLLocation) {
        self.tripId = tripId
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
        self.timestamp = location.timestamp
        self.accuracy = location.horizontalAccuracy
        self.altitude = location.altitude
        self.isSynced = false
    }
}
```

### SwiftData Query for Pending Sync

```swift
// Source: SwiftData @Query pattern [ASSUMED — stdlib]
func fetchUnsyncedPoints(tripId: String, context: ModelContext) throws -> [RoutePoint] {
    let descriptor = FetchDescriptor<RoutePoint>(
        predicate: #Predicate { $0.tripId == tripId && $0.isSynced == false },
        sortBy: [SortDescriptor(\.timestamp)]
    )
    return try context.fetch(descriptor)
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| CLLocationManager delegate + background task | `CLLocationUpdate.liveUpdates()` + `CLBackgroundActivitySession` | iOS 17 (2023) | Cleaner async/await API; old approach still works but is considered legacy |
| `ObservableObject` + `@Published` for auth state | `@Observable` macro + `@MainActor` | iOS 17 (2023) | Lighter weight; no `@Published` needed; properties observed automatically |
| Firestore document array for GPS trace | Subcollection + batch write | N/A (architectural best practice) | Document size limit; subcollections scale to unlimited points |
| CLPlacemark for POI categories | `MKLocalPointsOfInterestRequest` | iOS 13 (2019) for the request API | CLPlacemark returns nil categories; MKLocalPointsOfInterestRequest returns structured enum |
| `distanceFilter = 10` for background GPS | `distanceFilter = kCLDistanceFilterNone` | iOS 16.4 (2023) | Non-zero filter causes silent background suspension |

**Deprecated/outdated:**
- `NSLocationAlwaysUsageDescription` plist key: Replaced by `NSLocationAlwaysAndWhenInUseUsageDescription` (still needed: `NSLocationWhenInUseUsageDescription` too)
- SceneKit: Soft-deprecated at WWDC 2025 — not relevant to Phase 2 but noted from STATE.md
- Firestore test mode rules: Must be replaced in Phase 2 before any real user data is written

---

## Info.plist Changes Required

The current `Info.plist` is missing all location, photo, and background mode keys. Phase 2 must add:

| Key | Value | Reason |
|-----|-------|--------|
| `NSLocationAlwaysAndWhenInUseUsageDescription` | User-facing string | Required for requestAlwaysAuthorization |
| `NSLocationWhenInUseUsageDescription` | User-facing string | Required for requestWhenInUseAuthorization |
| `NSPhotoLibraryUsageDescription` | User-facing string | Required for Photos access |
| `UIBackgroundModes` → `location` | Array value | Required for background GPS |

If these keys are missing, `requestAlwaysAuthorization()` silently does nothing and the Photos permission dialog never appears.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Physical iOS Device | LOC-01, LOC-02 background GPS test | Must verify | iOS 18+ recommended | No fallback — background GPS cannot be tested on simulator |
| Firebase project (Firestore enabled) | AUTH-01 through AUTH-07, PLACE-04 | Assumed (INFRA-03 done) | 12.11.0 | — |
| Xcode 16.2+ | Firebase 12.x SPM requirement | Must verify | — | Upgrade required |

**Missing dependencies with no fallback:**
- Physical device for LOC-01/LOC-02 background GPS validation — this is a stated success criterion in the phase and cannot be verified on simulator

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | SwiftData `@Model` with `isSynced: Bool` pattern works for LOC-03 buffering | Standard Stack, Pattern 7 | Minor — may need Core Data alternative if SwiftData has iOS 17 bugs for this use case |
| A2 | `CLLocationUpdate.liveUpdates()` async stream is the right API (vs. CLLocationManager delegate with `.liveUpdates()`) | Pattern 3 | Medium — fallback to delegate pattern always available; test on device first |
| A3 | `@Observable` macro works with Firebase Auth listener without Sendable conformance issues | Pattern 1 | Low — Swift 6 strict concurrency may require additional actor annotations |
| A4 | MKLocalPointsOfInterestRequest returns results for small coordinate regions (200m radius) | Pattern 6 | Medium — may return empty results in rural areas; fallback: widen search radius to 500m |
| A5 | 2-decimal-place coordinate rounding for POI cache key provides adequate deduplication (~1.1km grid cell) | Pattern 6 | Low — can always adjust to 1 decimal (11km) or 3 decimal (110m) |
| A6 | `.spa` category is not in iOS 13 baseline — may not exist | MKPointOfInterestCategory Mapping | Low — handled by `default: nil` mapping; if present it maps to Wellness |
| A7 | Onboarding flow can use `TabView(.page)` with programmatic index advance | Architecture | Low — confirmed SwiftUI pattern; may prefer custom scroll-locked pager |

---

## Open Questions

1. **CLLocationUpdate vs CLLocationManager for LOC-01**
   - What we know: Both APIs work for background GPS. `CLLocationUpdate.liveUpdates()` is modern but has iOS 17 reliability issues. `CLLocationManager` delegate is older but well-tested on iOS 16.4+.
   - What's unclear: The project's minimum iOS target is not explicitly stated. If iOS 17+ only, the async stream API is preferred. If iOS 16 support is needed, use the delegate.
   - Recommendation: Use `CLLocationManager` delegate + `CLBackgroundActivitySession` for maximum reliability. The async stream is a discretionary upgrade.

2. **SwiftData ModelContainer threading model**
   - What we know: `ModelContext` is not thread-safe. Background GPS recording happens off the main thread.
   - What's unclear: Whether `@ModelActor` or explicit `ModelContext` passing is the right pattern for writing RoutePoints from a background Task.
   - Recommendation: Pass a `ModelContext` (not a shared container) into the `LocationManager` background task; use `@ModelActor` for the persistence service class.

3. **MKLocalPointsOfInterestRequest rate limits**
   - What we know: Apple documentation does not specify rate limits. The coordinate-key cache (PLACE-03) reduces calls.
   - What's unclear: Whether rapid sequential calls (processing a trip with many stops) will be throttled.
   - Recommendation: Implement the cache first. Add a 200ms delay between sequential calls as a precaution. The `actor` isolation on `PlaceCategoryService` serializes calls naturally.

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | Yes | Firebase Auth — email/password; no custom crypto |
| V3 Session Management | Yes | Firebase SDK keychain persistence; no custom session token |
| V4 Access Control | Yes | Firestore security rules: `request.auth.uid == userId` path matching |
| V5 Input Validation | Yes | Handle: alphanumeric + underscore, max 30 chars; email: Firebase Auth validates format |
| V6 Cryptography | No | Firebase handles all crypto; no custom implementation |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Unauthenticated Firestore access | Spoofing | Security rules: `request.auth != null` required on all user paths |
| Handle squatting / enumeration | Information Disclosure | `usernames` collection: only authenticated users can read (hide from unauthenticated) |
| Location data exfiltration | Information Disclosure | Firestore rules: users can only read `users/{their uid}/**` — no cross-user reads |
| Rapid handle availability polling | Denial of Service | Firestore rate limits + client-side 500ms debounce reduce load |
| Test mode rules left in production | Elevation of Privilege | **HIGH RISK** — FirebaseService.swift comment explicitly flags this; Phase 2 task 0 must deploy production rules |

---

## Sources

### Primary (HIGH confidence)
- Firebase Auth official docs — `createUser(withEmail:password:)`, `addStateDidChangeListener`, session persistence behavior [CITED: firebase.google.com/docs/auth/ios/password-auth]
- Apple Developer Forums — CLBackgroundActivitySession introduction and requirements [CITED: developer.apple.com/documentation/corelocation/clbackgroundactivitysession-3mzv3]
- Firebase Firestore — Transactions and batched writes, 500-op limit [CITED: firebase.google.com/docs/firestore/manage-data/transactions]
- Firebase Security Rules + Auth docs [CITED: firebase.google.com/docs/rules/rules-and-auth]
- iOS SDK header — MKPointOfInterestCategory complete list [VERIFIED: github.com/xybp888/iOS-SDKs/blob/master/iPhoneOS13.0.sdk/]
- Project codebase — FirebaseService.swift, AppDelegate.swift, Info.plist, NomadApp.swift [VERIFIED: grep + file reads]

### Secondary (MEDIUM confidence)
- twocentstudios.com/2024/12/02/core-location-modern-api-tips/ — Modern Core Location API pitfalls, CLBackgroundActivitySession lifetime, avoid iOS 17 for CLLocationUpdate [CITED]
- cropsly.com/blog/location-updates-changes-in-ios-16-4/ — Exact iOS 16.4 distanceFilter/desiredAccuracy requirements for background GPS [CITED]
- stphndxn.com — SwiftData + Firebase sync architecture (DTO pattern, repository layer) [CITED]
- Apple Developer Forums thread/726945 — Background location stop on iOS 16.4 confirmed as intentional change [CITED]
- RDP algorithm gist (yageek) — Swift polyline simplification pattern [CITED: gist.github.com/yageek/287843360aeaecdda14cb12f9fbb60dc]

### Tertiary (LOW confidence)
- SwiftPackageIndex Firebase version 12.11.0 — current as of search date 2026-04-05 [VERIFIED: swiftpackageindex.com]
- Firestore uniqueness via document IDs + batch write pattern — confirmed across multiple sources [MEDIUM]

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — Firebase already integrated; all other APIs are Apple stdlib; versions verified
- Architecture: HIGH — patterns are well-established iOS patterns for this specific problem domain
- Background GPS: MEDIUM — pitfalls are verified; exact async stream vs. delegate choice is discretionary
- POI mapping: MEDIUM — category list verified from SDK header; dimension mapping is design decision (no wrong answer, just needs a decision)
- Pitfalls: HIGH — iOS 16.4 change is documented and critical; confirmed from official Apple forums

**Research date:** 2026-04-05
**Valid until:** 2026-07-05 (stable APIs; Firebase version may update sooner)
