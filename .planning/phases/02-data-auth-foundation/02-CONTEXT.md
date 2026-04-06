# Phase 2: Data & Auth Foundation - Context

**Gathered:** 2026-04-05
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver a complete, device-tested data pipeline — background GPS recording that survives a locked screen for 10+ minutes, CLVisit-based trip detection, Ramer-Douglas-Peucker route simplification, MKLocalSearch place categorization, and the full Firebase Auth + onboarding flow — so that Phase 3's UI has real, correctly-structured data to display.

</domain>

<decisions>
## Implementation Decisions

### Onboarding Flow Structure
- **D-01:** Full-screen paged flow with progress indicator dots. One screen per step — no scrollable single page, no bottom sheet over globe. Clean, one-thing-at-a-time.
- **D-02:** Welcome screen first, before signup form: globe (or hero globe visual) as background, Playfair Display tagline, amber "Get started" CTA. Then email/password form on next screen.
- **D-03:** Onboarding step order: Welcome → Sign Up (email/password) → Handle → Location permission → Photos permission → Discovery scope → Home city confirm → Globe

### Handle Validation
- **D-04:** Live, debounced Firestore uniqueness check as the user types — 500ms debounce. Inline feedback: green checkmark (available) or red "already taken" under the field. No surprises at submit.

### Permissions Screens
- **D-05:** Each permission gets a custom pre-prompt explanation screen before the native iOS dialog fires. Location pre-prompt: "Background location keeps your route alive while you explore." Photos pre-prompt: explains photo matching by date/GPS. Two separate screens, two native dialogs.

### Discovery Scope Screen
- **D-06:** Two large tappable option cards. Each card has: an icon, a label ("Everywhere" / "Away from home only"), and a one-line description. Full-width layout. No toggle, no segmented control.

### Home City Setup
- **D-07:** Auto-detect from current location via CLGeocoder reverse-geocode to city name. Show the detected city for user confirmation ("Your home city: London — is this right?"). User can edit if wrong (text field opens). This happens as the last onboarding step after discovery scope.
- **D-08:** 50km geofence radius registered via CLLocationManager.startMonitoring(for: CLCircularRegion). Fixed — not user-adjustable.

### Auth State Management
- **D-09:** `@Observable AuthManager` class (not struct — Firebase listener must persist). Listens on `Auth.auth().addStateDidChangeListener`. Injected as `@Environment(\.authManager)` or `@EnvironmentObject`. Drives a top-level `@ViewBuilder` switch in ContentView:
  - `.unauthenticated` → OnboardingView
  - `.authenticated(user)` → GlobeView
  - `.loading` → stays on launch screen until Firebase resolves
- **D-10:** No @AppStorage token storage — rely entirely on Firebase's own keychain-backed persistence (`Auth.auth().currentUser`). Firebase SDK handles session persistence across restarts.

### Launch Transition
- **D-11:** For authenticated returning users, globe appears directly — no splash screen, no loading overlay. Firebase Auth resolves silently in background. Globe is the first visual.

### Firestore Schema
- **D-12:** Trips live in `users/{uid}/trips/{tripId}` subcollection. Not top-level collection. Security rules: authenticated user can read/write only `users/{their uid}/**`.
- **D-13:** Full GPS trace stored in `users/{uid}/trips/{tripId}/routePoints/{pointId}` subcollection. Written in batches from SwiftData after trip ends. Not stored as an array on the trip doc (1MB Firestore limit).
- **D-14:** Trip document denormalized fields (all required — downstream reads depend on these without extra queries):
  - `routePreview: [[Double]]` — 50-point simplified GPS trace (lat/lon pairs), for globe card + map preview
  - `visitedCountryCodes: [String]` — ISO codes for globe country highlighting
  - `placeCounts: [String: Int]` — `{Food: 3, Culture: 1, Nature: 0, Nightlife: 2, Wellness: 0, Local: 1}`
  - `cityName: String` — trip header display
  - `startDate: Timestamp`, `endDate: Timestamp` — trip date range, used for photo matching
  - `stepCount: Int` — from HealthKit
  - `distanceMeters: Double`
  - `userId: String` — for future v2 cross-user queries

### User Document
- **D-15:** `users/{uid}` document fields:
  - `handle: String` — unique, validated at write time
  - `email: String`
  - `homeCityName: String`
  - `homeCityLatitude: Double`, `homeCityLongitude: Double`
  - `discoveryScope: String` — "everywhere" | "awayOnly"
  - `geofenceRadius: Double` — 50000.0 (meters), stored for future adjustability
  - `createdAt: Timestamp`
  - `onboardingComplete: Bool` — gate for post-onboarding navigation

### SwiftData Local Model (Route Points Buffer)
- **D-16:** `RoutePoint` SwiftData model for local buffering before Firestore sync:
  - `tripId: String`
  - `latitude: Double`, `longitude: Double`
  - `timestamp: Date`
  - `accuracy: Double`
  - `altitude: Double`
  - `isSynced: Bool` — false until written to Firestore subcollection

### Claude's Discretion
- Exact onboarding screen animation/transition style (slide or fade between pages)
- Progress dots visual style (filled circles, thin bars, etc.)
- Welcome screen tagline copy
- Location pre-prompt and Photos pre-prompt exact copy
- SwiftData model for Trip entity (fields beyond RoutePoint)
- Firestore batch write size for routePoints (can decide 400 or 500 per batch)
- Firebase security rules exact syntax
- RDP simplification epsilon values (per REQUIREMENTS.md: ~500pt detail, ~50pt preview)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Authentication & Onboarding requirements
- `.planning/REQUIREMENTS.md` §Authentication & Onboarding (AUTH-01 through AUTH-07) — All auth and onboarding requirements, including handle uniqueness, permission grants, discovery scope, home city geofence

### Location pipeline requirements
- `.planning/REQUIREMENTS.md` §Location Pipeline (LOC-01 through LOC-06) — Background GPS, CLBackgroundActivitySession, SwiftData buffering, RDP simplification, CLVisit monitoring, discovery scope enforcement

### Place categorization requirements
- `.planning/REQUIREMENTS.md` §Place Categorization (PLACE-01 through PLACE-04) — MKLocalPointsOfInterestRequest (NOT CLPlacemark), 6-dimension mapping, coordinate-keyed cache, placeCounts per trip

### Design system (established in Phase 1)
- `Nomad/DesignSystem/AppColors.swift` — Color.Nomad namespace (cream, warmCard, amber, globeBackground, destructive)
- `Nomad/DesignSystem/AppFont.swift` — AppFont enum (title, subheading, body, caption, buttonLabel)
- `Nomad/DesignSystem/PanelGradient.swift` — .panelGradient() modifier — MUST be applied to all bottom sheet panels

### Existing Firebase integration
- `Nomad/Firebase/FirebaseService.swift` — Existing stub (writeStubUser/readStubUser). Phase 2 replaces this with real Auth + user document writes.
- `Nomad/App/AppDelegate.swift` — Firebase initialization pattern (FirebaseApp.configure() in didFinishLaunching)

### Architecture decisions
- `.planning/STATE.md` §Key Decisions Made During Init — MKLocalPointsOfInterestRequest (not CLPlacemark), Firebase 12.x via SPM, existing globe is MKMapView hybridFlyover

### Phase 1 context (established patterns)
- `.planning/phases/01-foundation-spikes-globe-shell/01-CONTEXT.md` — Color palette, typography scale, panel gradient style, all of which onboarding screens must inherit

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Color.Nomad.*` — Full color namespace already defined; all onboarding screens use `.cream`, `.warmCard`, `.amber`, `.globeBackground`
- `AppFont.*` — Typography functions; use `.title()`, `.subheading()`, `.body()`, `.caption()`, `.buttonLabel()` throughout onboarding
- `.panelGradient()` — View modifier; apply to all panel/sheet surfaces in onboarding
- `NomadApp.swift` — Already uses `@UIApplicationDelegateAdaptor(AppDelegate.self)`; AuthManager should be injected here as `@StateObject` / `@State`
- `FirebaseService.swift` — Stub; contains `db = Firestore.firestore()` pattern to reuse

### Established Patterns
- SwiftUI app entry: `NomadApp: App` with UIApplicationDelegateAdaptor — Firebase is already initializing here; AuthManager listener should start here too
- Bottom sheet pattern: `.sheet()` attached to parent, nested sheets inside child view — validated INFRA-02 in Phase 1 (see ProfileSheet.swift for reference)
- `GlobeView` is the authenticated home — ContentView currently routes straight to GlobeView; Phase 2 adds an auth gate in front

### Integration Points
- `NomadApp.swift` → inject `AuthManager` as environment object, switch between `OnboardingView` and `GlobeView`
- `ContentView.swift` → currently shows GlobeView directly; Phase 2 replaces this with auth-gated routing
- `FirebaseService.swift` → Phase 2 expands to `UserService` (handle uniqueness check, user doc write) + `TripService` (trip + routePoints writes)
- `GlobeView` → will need to observe `AuthManager` to show/hide active trip indicator (Phase 3 builds this; Phase 2 just sets up the data layer)

</code_context>

<specifics>
## Specific Ideas

- Welcome screen: globe as the hero visual — the globe IS the product, so it belongs on the first screen the user ever sees
- Pre-prompt for location: frame it as enabling the experience, not asking for a permission. "So Nomad can track your journey in the background, even when your phone is locked."
- Discovery scope cards: the "Everywhere" card should feel slightly more adventurous/exploratory in tone; "Away from home only" is the privacy-respecting default
- Home city confirmation: show it at the END of onboarding (after permissions are already granted so CLGeocoder can run), with a simple "Looks right?" + confirm button
- Live handle check: visual feedback should feel smooth — a spinner while checking, then checkmark or X. Not aggressive error states.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

Background recording UX (active trip indicator on globe, force-quit behavior) was noted but deferred — that's a Phase 3 UI concern once the data layer exists.

</deferred>

---

*Phase: 02-data-auth-foundation*
*Context gathered: 2026-04-05*
