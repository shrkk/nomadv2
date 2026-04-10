# Architecture

**Analysis Date:** 2026-04-10

## Pattern Overview

**Overall:** MVVM with Observable state management (SwiftUI Observation framework), layered by concern with clear separation between UI, services, and data models. Firebase as the single source of truth for trip and user data.

**Key Characteristics:**
- SwiftUI-native with `@Observable` for reactive state management
- Firestore as primary persistent store; SwiftData for local route recording buffers
- Service layer (`TripService`, `UserService`, `LocationManager`) decouples views from Firebase
- ViewModel pattern per major feature (GlobeViewModel, CountryDetailViewModel)
- Auth-gated routing at app entry point with onboarding state machine
- ActivityKit Live Activity for continuous recording feedback

## Layers

**Presentation (UI):**
- Purpose: SwiftUI views, sheets, onboarding screens, and interactive components
- Location: `Nomad/App/`, `Nomad/Globe/`, `Nomad/Sheets/`, `Nomad/Components/`, `Nomad/Onboarding/`
- Contains: Views, sheets, coordinators, view-specific state
- Depends on: ViewModels, services (via environment), design tokens
- Used by: SwiftUI rendering engine

**ViewModels & State Management:**
- Purpose: Drives reactive UI updates; fetches data and manages feature-specific state
- Location: `Nomad/Globe/GlobeViewModel.swift`, `Nomad/Sheets/CountryDetailSheet.swift` (via CountryDetailViewModel)
- Contains: `@Observable` classes, coordinators (OnboardingCoordinator)
- Depends on: Services, auth state, Firestore models
- Used by: Presentation layer

**Service Layer:**
- Purpose: Encapsulate business logic, Firebase operations, location tracking, and categorization
- Location: `Nomad/Data/`, `Nomad/Auth/`, `Nomad/Location/`
- Contains: TripService, UserService, LocationManager, PlaceCategoryService, WeatherService, RouteSimplifier
- Depends on: Models, Firebase SDK, CoreLocation, MapKit
- Used by: ViewModels, coordinators

**Data Models:**
- Purpose: Type-safe representations of Firestore documents and local records
- Location: `Nomad/Data/Models/`, `Nomad/Data/FirestoreSchema.swift`
- Contains: TripDocument, TripLocal, RoutePoint, CityCluster
- Depends on: Firebase types, CoreLocation
- Used by: Services, ViewModels

**Infrastructure:**
- Purpose: Firebase setup, GeoJSON parsing, design system
- Location: `Nomad/Firebase/`, `Nomad/GeoJSON/`, `Nomad/DesignSystem/`
- Contains: FirebaseService, GeoJSONParser, AppColors, AppFont, PanelGradient
- Depends on: Firebase SDK, external APIs
- Used by: Services, views

## Data Flow

**App Launch → Globe Display:**

1. `NomadApp.init()` calls `FirebaseApp.configure()`
2. `@State` backing stores instantiate `AuthManager` and `UserService`
3. `AuthManager.init()` registers auth state listener (Firebase)
4. Auth state changes trigger root routing: .loading → .unauthenticated (OnboardingView) or .authenticated (GlobeView)
5. `GlobeView` loads `GlobeViewModel`
6. `GlobeViewModel.loadGlobeData()` runs async:
   - `GeoJSONParser.loadCountries()` fetches local GeoJSON
   - `TripService.fetchTrips(userId)` queries Firestore (scoped to current user)
   - `TripService.fetchVisitedCountryCodes(userId)` retrieves aggregated countries
   - `UserService.fetchUserDocument()` loads home city coordinate
   - Test trip data injected for route visualization testing
   - `PhotoManager` fetches random device gallery image per trip date range

**Onboarding Flow:**

1. `OnboardingView` manages `OnboardingCoordinator`
2. Coordinator tracks step position (welcome → signUp → handle → permissions → homeCity)
3. Each screen accumulates data into coordinator properties (email, handle, discoveryScope, etc.)
4. `AuthManager.signUp()` or `signIn()` called by SignUpScreen
5. Auth state listener in AuthManager triggers authenticated → check onboardingComplete
6. `HomeCityScreen` calls `AuthManager.markOnboardingComplete()` and writes coordinator data to Firestore
7. App routes to GlobeView on next render cycle

**Trip Recording Lifecycle:**

1. User taps "Start Trip" → generates tripId, sets city name
2. `LocationManager.startRecording(tripId)` begins:
   - Creates `CLBackgroundActivitySession` (keeps GPS active when backgrounded)
   - Subscribes to `CLLocationUpdate.liveUpdates()` async stream
   - Filters locations with accuracy < 50m
   - Writes filtered `RoutePoint` records to SwiftData ModelContext (marked isSynced=false)
   - Accumulates distance incrementally between consecutive points
   - Pushes Live Activity update every 30 seconds
3. User taps "Stop Trip" and names it
4. `TripService.finalizeTrip()` called with RoutePoint array:
   - Simplifies route via Ramer-Douglas-Peucker algorithm
   - Samples stops (every ~20th point) for POI categorization
   - `PlaceCategoryService.categorizeStops()` reverse-geocodes and queries MapKit POI database
   - `CLGeocoder.reverseGeocodeLocation()` detects country codes from sample coordinates
   - Writes trip document to Firestore (`users/{uid}/trips/{tripId}`)
   - Batch-writes route points to subcollection in 400-operation chunks (Firestore limit 500)
5. `TripService.updateUserVisitedCountries()` aggregates new country codes into user document

**Country Detail → Trip Detail Flow:**

1. User taps country overlay on globe
2. `GlobeViewModel.showCountryDetailSheet()` displays `CountryDetailSheet`
3. `CountryDetailViewModel.load()` clusters trips by proximity and loads per-cluster data
4. Photos and temperatures fetched asynchronously per cluster (memory eviction for off-screen clusters)
5. User selects city cluster → taps trip card
6. `TripDetailSheet` displayed with:
   - `TripService.fetchRouteCoordinates()` retrieves full route from Firestore subcollection
   - Pause-based stop detection (dwell >= 90s within 40m radius)
   - MapKit route overlay rendering
   - Photo gallery fetched by date range + GPS bounding box
7. User can open route in Apple Maps via MKLaunchOptions

**State Management:**

- `AuthManager` is `@State` in `NomadApp` and injected as environment — single source of auth truth
- `UserService` injected as environment for onboarding data accumulation
- `LocationManager` injected as environment for recording lifecycle
- `GlobeViewModel` created per GlobeView, retains observer for live Firestore updates
- `OnboardingCoordinator` lives in `NomadApp` to survive mid-flow auth state changes
- Local trip recordings stored in SwiftData; synced to Firestore on finalization

## Key Abstractions

**AuthManager:**
- Purpose: Firebase auth state listener and sign-in/sign-up coordinator
- Examples: `Nomad/Auth/AuthManager.swift`
- Pattern: `@Observable @MainActor` class with auth state enum and onboarding flag. Listener handle stored in nonisolated box for safe deinit.

**GlobeViewModel:**
- Purpose: Central store for globe state, trip fetching, and country focus management
- Examples: `Nomad/Globe/GlobeViewModel.swift`
- Pattern: `@Observable @MainActor` class. Manages countries, trips, visited codes, photos, and route overlays. Exposes methods for sheet navigation and route loading.

**OnboardingCoordinator:**
- Purpose: State machine for multi-step onboarding with data accumulation
- Examples: `Nomad/Onboarding/OnboardingCoordinator.swift`
- Pattern: `@Observable @MainActor` enum-driven step tracking with mutable property bag for email, handle, home city, etc.

**TripService:**
- Purpose: Trip finalization, route simplification, POI categorization, and Firestore persistence
- Examples: `Nomad/Data/TripService.swift`
- Pattern: `@MainActor` service with public methods for finalize, sync, fetch. Private helpers for geocoding, sampling, and bounding box computation.

**LocationManager:**
- Purpose: Background GPS recording pipeline with live activity updates
- Examples: `Nomad/Location/LocationManager.swift`
- Pattern: `@Observable @MainActor` class. Holds CLBackgroundActivitySession and async stream subscription. Writes to SwiftData; lifecycle controlled via startRecording/stopRecording.

**FirestoreSchema:**
- Purpose: Type-safe path constants and reference builders to prevent string literal scatter
- Examples: `Nomad/Data/FirestoreSchema.swift`
- Pattern: Static helper functions returning `DocumentReference` and `CollectionReference` with nested enums for field key strings.

**RouteSimplifier:**
- Purpose: Ramer-Douglas-Peucker route simplification and coordinate extraction
- Examples: `Nomad/Location/RouteSimplifier.swift`
- Pattern: Static methods for simplifyRoute and coordinate pairing/flattening.

## Entry Points

**NomadApp:**
- Location: `Nomad/App/NomadApp.swift`
- Triggers: App launch via @main attribute
- Responsibilities: Root app struct, Firebase initialization, AuthManager/UserService/LocationManager setup, auth-gated routing (loading → onboarding or globe)

**GlobeView:**
- Location: `Nomad/Globe/GlobeView.swift`
- Triggers: Displayed when authManager.authState == .authenticated && onboardingComplete == true
- Responsibilities: Renders GlobeMapView with country overlays, trip pinpoints, home city pin. Manages sheet presentation (CountryDetailSheet, ProfileSheet, TripDetailSheet).

**OnboardingView:**
- Location: `Nomad/Onboarding/OnboardingView.swift`
- Triggers: Displayed when unauthenticated or onboardingComplete == false
- Responsibilities: Routes between onboarding screens via coordinator.currentStep. Manages auth flow and data accumulation.

**ContentView:**
- Location: `Nomad/App/ContentView.swift`
- Triggers: Phase 1 stub; not currently used in active app flow
- Responsibilities: Design system validation (typography, colors, panel gradient)

## Error Handling

**Strategy:** Try-catch with logging to console and optional error state exposure in ViewModels. Failed Firestore operations leave UI in previous state without error dismissal.

**Patterns:**
- `TripService` methods throw; callers use `try?` to silence and fall back to cached state
- `LocationManager` silently handles accuracy filter failures (< 50m accuracy requirement)
- Auth errors surfaced via `GoogleSignInError` enum with localized descriptions
- Network failures in `AuthManager.syncOnboardingStatus()` silently fallback (user re-enters onboarding)
- Photo library authorization checked via `PHPhotoLibrary.authorizationStatus()` before fetch; missing permission silently skips

## Cross-Cutting Concerns

**Logging:** Console via `print()` statements with `[Globe]`, `[Location]`, `[Auth]` prefixes for filtering

**Validation:**
- Email/password validation in SignUpScreen (basic regex)
- Handle uniqueness checked via `FirestoreSchema.usernameDoc()` reservation in Firestore
- Location accuracy filtered < 50m to reduce low-quality GPS noise

**Authentication:**
- Firebase Auth primary (email/password + Google Sign-In)
- Auth state observable via AuthManager
- User UID scoped all Firestore reads/writes (T-03-01: enforced at TripService call sites)
- onboardingComplete flag in UserDefaults (fast path) + Firestore (source of truth on new device)

**Isolation:**
- `@MainActor` isolation on all `@Observable` classes for SwiftUI safety
- `@preconcurrency` imports on Firebase SDK (concurrency not yet fully modeled)
- CLBackgroundActivitySession held as stored property in LocationManager (not local variable) to prevent dealloc-triggered GPS stop

---

*Architecture analysis: 2026-04-10*
