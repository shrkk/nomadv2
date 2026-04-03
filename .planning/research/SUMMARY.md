# Project Research Summary

**Project:** Nomad — Native iOS Travel Logging App
**Domain:** iOS travel logging / traveler identity app
**Researched:** 2026-04-03
**Confidence:** MEDIUM-HIGH

---

## Executive Summary

Nomad is a native iOS travel app in a well-charted domain (Polarsteps, Google Timeline, Strava), but its distinguishing design decision — a persistent interactive 3D globe as the home view — introduces a non-obvious architectural trap that must be resolved in the first week. **MapKit cannot render a free-rotating 3D globe on iPhone.** The `.standard` and `.imagery` map styles stay flat regardless of zoom level; the globe appearance in Apple Maps is internal to that app and is not an API surface. The globe home view must be built with RealityKit (preferred, iOS 18+) wrapping an `ARView`, or via `UIViewRepresentable` around `ARView` in `.nonAR` mode for iOS 17 support. SceneKit is out: soft-deprecated at WWDC 2025. This single architectural decision affects the entire home screen and must be confirmed on a physical device before any other work begins.

Beyond the globe, the stack is clean and low-risk: SwiftUI iOS 17+, CLLocationManager (not the newer CLLocationUpdate, which has per-version accuracy bugs), Firebase 12.x via Swift Package Manager, and native Apple APIs throughout (HealthKit for steps, PhotoKit for galleries). Firebase 12.x carries one important breaking change: the `FirebaseFirestoreSwift` module is gone — Codable support is now built into `FirebaseFirestore` directly. The Firestore data model must be designed up front around denormalized read patterns (visited country codes on the user document, route previews embedded in each trip document) because Firestore lacks geo-query support and the globe highlight layer needs data available at app launch without subcollection queries.

The two biggest runtime risks are both silent: background location stops delivering updates after iOS 16.4 if `distanceFilter` or `desiredAccuracy` are set incorrectly, and place category data is simply not available from CoreLocation reverse geocoding — CLPlacemark returns nil categories for restaurants, museums, and parks. Both of these affect core features (trip recording accuracy and the traveler archetype system). Both require explicit mitigation before feature work begins.

---

## Key Findings

### Recommended Stack

The stack is Apple-ecosystem-first by project constraint, which turns out to be the right call. SwiftUI iOS 17.0 is the recommended deployment floor — it gives MapKit for SwiftUI maturity, `presentationDetents` for bottom sheets, `CLBackgroundActivitySession`, and `@Observable`. Firebase 12.x is installed via Swift Package Manager (CocoaPods is deprecated for Firebase). The entire stack is third-party-dependency-light: no Mapbox, no Google Maps, no third-party bottom sheet libraries.

**Core technologies:**

- **RealityKit + ARView (UIViewRepresentable):** Globe home view — MapKit explicitly cannot do this; SceneKit soft-deprecated WWDC 2025; RealityKit is the correct successor, but `RealityView` requires iOS 18, so wrap `ARView` in a `UIViewRepresentable` for iOS 17 support
- **MapKit for SwiftUI (`Map`, `MapPolyline`):** All non-globe map views — route display, trip detail, POI search; use `UIViewRepresentable` wrapping `MKMapView` for the globe view itself to control overlay lifecycle
- **CLLocationManager (not CLLocationUpdate):** Background GPS — `CLLocationUpdate` has iOS 17 accuracy bugs, lacks `distanceFilter`, and is not recommended as a primary engine until iOS 18+
- **Firebase 12.x (FirebaseAuth, FirebaseFirestore, FirebaseStorage):** Backend — import `FirebaseFirestore` directly for Codable; `FirebaseFirestoreSwift` module removed in v11+
- **SwiftData:** Local offline buffer for active route points and last-20 trip cache — use separate model types from Firestore Codable types, never share `@Model` with Firestore decoding path
- **PhotoKit (PHPhotoLibrary direct access):** Trip photo galleries — do NOT use `PHPickerViewController` for this use case; iOS 17 picker strips location metadata; direct library access preserves it
- **HealthKit (HKStatisticsQuery, read-only):** Per-trip step counts and lifetime stats; requires physical device for testing (unavailable on simulator)

**Critical version note:** `RealityView` requires iOS 18. For iOS 17 minimum, use `ARView` in `.nonAR` camera mode wrapped in `UIViewRepresentable`. Plan to migrate to `RealityView` when the deployment floor raises.

### Expected Features

**Must have (table stakes):**
- Background GPS route recording (manual start/stop) — data foundation; without this nothing else renders
- Visited countries globe with country highlight overlay — the core identity hook and primary differentiator
- Trip timeline / history list — users need to see what was logged; basic accountability
- Photo attachment to trips (auto-matched from Apple Photos by date and location) — competitors require manual upload; this is a genuine gap to close
- Offline-first operation — travelers are frequently without signal; data loss here causes immediate churn
- Country and trip statistics — "countries visited" is the number-one vanity stat for travelers

**Should have (competitive):**
- Traveler archetype system (8 archetypes, 6-7 place-type categories) — the "personality mirror" hook that gives users identity to share and reason to keep logging; built on MKLocalSearch place data not reverse geocoding
- Strava-style route map (GPS trace + named place pins) — the shareable moment; the reason to screenshot and post
- Shareable trip card and Traveler Passport card — Strava's most powerful growth mechanic; must be beautiful on launch
- HealthKit steps per trip — grounds travel in something physical; "28,000 steps through Kyoto" is a meaningful stat

**Defer (v2+):**
- Travel Wrapped annual recap — needs accumulated data; design data model correctly from day one so this is additive, not a rewrite
- Friends social graph — profile-viewing only (not a feed); defer to v2 but design user handle system and Firestore structure to support it
- Push notifications for trip detection prompts — add FirebaseMessaging in v2 once core experience is solid

**Anti-features (do not build in any version):**
- Activity feed / social timeline — significant moderation infrastructure; users prefer direct sharing anyway
- In-app booking, itinerary planning, recommendations engine
- Leaderboards or public country count comparisons
- AI travel recommendations

### Architecture Approach

The recommended pattern is MVVM at the view layer with `@Observable` (iOS 17+) + Clean Architecture domain/data layers + a centralized `AppRouter` for navigation. The globe's requirement to persist as a backdrop across all sheet presentations rules out `NavigationStack` as the primary navigation primitive. Instead, two nested `.sheet` slots are attached to the root `ContentView`: the first presents the Profile sheet, the second is nested inside the Profile sheet and presents Trip Detail. A shared `@Observable AppRouter` injected via `@Environment` controls both slots. This is the highest architectural risk in the app — SwiftUI allows only one active sheet per view, and presenting nested sheets incorrectly causes silent failures or unexpected dismissals. This interaction must be prototyped and validated before any feature depends on it.

**Major components:**

1. **AppRouter + ContentView:** Root navigation state machine; owns globe as persistent background + both sheet slots; must be validated in Phase 1
2. **GlobeView + GlobeViewModel:** RealityKit/ARView sphere with NASA Blue Marble texture + GeoJSON country overlays; `UIViewRepresentable` wrapping `MKMapView` for country polygon highlights; owns `MapCameraPosition` for animated country zoom
3. **LocationService (Actor):** Manages CLLocationManager lifecycle; two-phase mode (passive CLVisit + significant change for detection, standard updates for active recording); buffers coordinates to SwiftData; publishes location events
4. **TripRepository:** Read/write trips from Firestore; mirrors active trip to SwiftData; denormalized `visitedCountryCodes` on user document and `routePreview` (~50 points) at trip document level
5. **RouteProcessor:** Ramer-Douglas-Peucker simplification on background actor before any MapKit call; raw trace → 200-500pt simplified → 50pt preview; use SwiftSimplify or Simplify-Swift
6. **PhotosService:** PHAsset query by date window + coordinate bounding box; always access PHPhotoLibrary directly (not picker) to preserve location metadata
7. **ArchetypeEngine:** Computes traveler archetype from denormalized `placeCounts` at trip level; weighted by recency; requires minimum ~3 trips before result is meaningful

**Firestore key design decisions:**
- `visitedCountryCodes: [String]` denormalized on user document — globe needs it at launch without a trips collection scan
- `routePreview: [GeoPoint]` (~50 points) embedded in trip document — globe pin previews load without fetching routePoints subcollection
- `placeCounts: { "restaurant": 3, "museum": 1 }` denormalized at trip level — archetype computation is a single trips query
- Full GPS trace stored in `routePoints/` subcollection — fetched on demand only in TripDetailView
- No native geo-query support in Firestore — client-side bounding box filter is fine for v1 (typically < 100 trips per user)

### Critical Pitfalls

1. **MapKit globe does not exist on iPhone** — MapKit's `.standard` style stays flat on iPhone regardless of zoom; Apple Developer Forums confirm no API for free-rotating globe. Use RealityKit (`ARView` in `.nonAR` mode on iOS 17, `RealityView` on iOS 18+). Prototype on a physical device in week 1 before designing the home screen around assumptions.

2. **Background location silently stops on iOS 16.4+ with wrong settings** — iOS 16.4 changed background delivery rules: any non-zero `distanceFilter` or accuracy coarser than `kCLLocationAccuracyHundredMeters` causes silent suspension even with Always permission. Required combination: `allowsBackgroundLocationUpdates = true`, `distanceFilter = kCLDistanceFilterNone`, `desiredAccuracy = kCLLocationAccuracyHundredMeters` or better. Test by locking screen for 10 minutes on a real device — simulator does not simulate this.

3. **Place category data is not available from reverse geocoding** — `CLPlacemark.areasOfInterest` returns nil for restaurants, shops, parks, and most everyday venues. `MKPointOfInterestCategory` is only available on `MKMapItem` objects returned from `MKLocalSearch`. The entire traveler archetype system requires an explicit place categorization source. Decide before the archetype phase: use `MKLocalPointsOfInterestRequest` (free, ~30 Apple categories, no attribution required) or Foursquare Places API (free tier 100K calls/day but requires visible "Powered by Foursquare" attribution). Google Places pricing changed in early 2025 — no longer viable.

4. **SceneKit is soft-deprecated (WWDC 2025)** — do not start new development on SceneKit; Apple has put it in maintenance-only mode. All globe rendering work should use RealityKit.

5. **Country GeoJSON requires offline pre-simplification before globe renders** — raw Natural Earth or similar GeoJSON for a country like Russia or Canada contains tens of thousands of coordinate points. Loading 195 countries simultaneously can exceed 100,000 total polygon points, causing MapKit to lock up or partially render. Pre-simplify offline (use `mapshaper` with tolerance ~0.1–0.5 degrees) before bundling with the app. Use `MKMultiPolygon` to batch rendering. Load and parse GeoJSON off the main thread.

6. **Firebase 12.x module restructure** — `FirebaseFirestoreSwift` module is removed. Import `FirebaseFirestore` directly for Codable support. `Timestamp` moved to `FirebaseCore`. Initialize Firebase via `AppDelegate` even in SwiftUI lifecycle apps (use `@UIApplicationDelegateAdaptor`).

7. **Stacked sheets have one-slot-per-view limit** — SwiftUI allows only one `.sheet()` per view hierarchy entry point at a time. Presenting a second sheet from inside a first sheet requires nesting the second `.sheet` modifier inside the first sheet's content view, not attaching both to the same parent. Use `AppRouter` with two explicit slots. Prototype this navigation pattern in Phase 1 — everything stacked-sheet-dependent fails if this is not proven first.

---

## Implications for Roadmap

Based on combined research, the dependency chain is: globe infrastructure must work → location pipeline must work → trip data must flow into Firestore → features layer on top. The two highest-risk items (globe rendering approach and stacked sheet navigation) must both be validated as technical spikes before any feature work begins.

### Phase 1: Foundation Spikes and Infrastructure

**Rationale:** Two critical architectural unknowns must be resolved before any feature work — the globe rendering approach (MapKit confirmed inadequate; RealityKit/ARView approach must be validated on device) and the stacked sheet navigation pattern (SwiftUI limitation confirmed; AppRouter approach must be proven). Neither can be safely assumed to work without a running prototype. Additionally, Firebase connection and the GeoJSON polygon pipeline must be established early because they are dependencies for nearly everything else.

**Delivers:** A running shell app with a rotating globe backdrop, two working sheet slots (Profile sheet → Trip Detail sheet, dismissible in order), GeoJSON country polygons rendering at globe scale without stutter, and a Firebase-connected user document. No real feature logic — pure architectural validation.

**Addresses:** Globe home view (architectural risk), stacked sheet navigation, GeoJSON polygon performance
**Avoids:** Globe rendering dead end (Pitfall 1), stacked sheet silent failure (Pitfall 7/10), polygon lag (Pitfall 5)
**Research flag:** This phase NEEDS a dedicated spike session. The globe rendering approach (ARView vs RealityKit vs iOS version decision) must be settled here with hands-on device testing. Do not proceed to Phase 2 until globe renders on a physical iPhone without stutter.

**Decisions that must be made in this phase:**
- iOS minimum deployment target: 17.0 (ARView) vs 18.0 (RealityView). This affects globe implementation path.
- Auth strategy: Sign in with Apple only vs email/password — determines Firebase Auth setup.
- Place categorization source: MKLocalPointsOfInterestRequest vs Foursquare — determines archetype data architecture.

### Phase 2: Location Pipeline and Data Foundation

**Rationale:** Location data is the foundation for every feature downstream. The trip recording pipeline (CLLocationManager → SwiftData buffer → RouteProcessor simplification → Firestore write) must be established with correct iOS 16.4+ background settings before UI is built on top of it. The Firestore data model must also be finalized here — changing it after archetype and passport features are built is expensive.

**Delivers:** Working background GPS recording (validated on physical device with screen locked), SwiftData local buffer for active trips, Ramer-Douglas-Peucker route simplification pipeline, Firestore trip document write with denormalized fields (routePreview, placeCounts, visitedCountryCodes), and place categorization via MKLocalSearch.

**Addresses:** GPS trace recording, offline-first data capture, Firestore schema
**Avoids:** iOS 16.4 background silence bug (Pitfall 2), GPS polyline lag from unthrottled points (Pitfall 12), SwiftData + Firestore model collision (separate model types from day one)
**Research flag:** Background location behavior on iOS 16.4+ has known edge cases. Test on a physical device with screen locked for 10+ minutes before declaring this phase complete. Do not test on simulator.

### Phase 3: Core User Journey (Globe → Trip → Detail)

**Rationale:** Once the infrastructure from Phases 1 and 2 is proven, the primary user journey can be assembled. This is the first phase where real user-visible features come together: the globe shows visited countries, tapping a trip pin opens the Profile sheet, tapping a trip opens the Detail sheet with a route map.

**Delivers:** Trip list reading from Firestore/SwiftData cache in Profile sheet; globe country highlight layer driven by `visitedCountryCodes`; trip pin annotations on globe with tap → Detail sheet; route polyline (simplified) in Trip Detail map; photo gallery (PHAssets matched by date + location bounding box); HealthKit step count per trip.

**Addresses:** Visited countries globe, trip timeline, photo gallery, HealthKit steps, route visualization
**Avoids:** PHPickerViewController location metadata strip (use PHPhotoLibrary direct), PHAsset limited access mode fallback (Pitfall 11), MKPolyline lag (apply RouteProcessor before render)
**Research flag:** Photo matching on date + bounding box is documented but has edge cases (iCloud shared photos have nil location). Build graceful fallback (date-only match) from the start.

### Phase 4: Trip Detection and Recording UX

**Rationale:** The hybrid auto-detection model (CLVisit + geofence departure → notification prompt) requires careful implementation to avoid being annoying or getting flagged by App Store reviewers. This phase adds the detection layer on top of the already-working recording pipeline from Phase 2.

**Delivers:** CLVisit + significant location change passive detection; geofence departure notification ("Looks like you left [City]. Start a Nomad trip?"); manual trip start/stop UI in Profile sheet; active trip indicator (blue location pill in status bar); trip end flow (RouteProcessor, photo match, step query, Firestore write); discovery scope enforcement (home city exclusion logic).

**Addresses:** Hybrid trip detection, manual start/stop, discovery scope setting, onboarding flow
**Avoids:** Always-on GPS battery drain when no trip is active (switch to CLVisit mode on trip end), App Store review rejection for vague background location justification (write two-paragraph Review Notes explaining detection flow), force-quit losing background delivery
**Research flag:** App Store review scrutiny for background location with `UIBackgroundModes: location` is high. Write the Review Notes justification before submission, not after rejection. Implement two-step permission flow (whenInUse at onboarding, upgrade to Always when user enables auto-detect).

### Phase 5: Traveler Passport and Archetype System

**Rationale:** The identity layer (Passport view, archetype label, stats) depends on having real trip data with place category counts accumulated from Phase 3's MKLocalSearch categorization. This phase reads from the denormalized `placeCounts` already written to Firestore in Phases 2-3.

**Delivers:** Traveler Passport view with world map + country stats; 8-archetype system computed from denormalized `placeCounts` across all trips (weighted by recency); archetype label + distribution chart; shareable trip card and Passport card (UIGraphicsImageRenderer snapshot); lifetime stats (countries, distance, days, steps).

**Addresses:** Traveler archetype, Passport stats, shareable cards
**Avoids:** Reverse geocoding for categories (it returns nil — use MKLocalSearch pipeline from Phase 2), archetype computation before minimum data (require ~3 trips before displaying archetype)
**Research flag:** The archetype scoring algorithm (weighted by recency, >35% threshold for primary archetype, handling tied categories) is original design. Validate against real logged trip data before presenting to users — the thresholds may need tuning. No research-phase needed, but plan an internal review with sample data.

### Phase 6: Onboarding and Polish

**Rationale:** Onboarding flow, permission requests, and design polish come last — not because they are unimportant, but because the correct permission flows (two-step location, HealthKit with privacy policy URL, Photos full vs limited access) can only be designed correctly once the feature they enable is built and reviewable by App Store reviewers.

**Delivers:** Complete onboarding (handle setup, location permission two-step, Photos access, discovery scope choice); App Store-ready permission flows with correct Info.plist strings; Playfair Display + Inter design system applied consistently; privacy policy URL live before submission.

**Addresses:** Onboarding, permission flows, design system consistency
**Avoids:** Cold-requesting Always location permission (App Store rejection pattern), HealthKit submission without live privacy policy URL (auto-rejection, Pitfall 13), vague NSPhotoLibraryUsageDescription (reviewer rejection)

### Phase Ordering Rationale

- Phase 1 before everything: the globe rendering approach is unvalidated and the stacked sheet pattern is architecturally risky; both must be proven before any feature depends on them
- Phase 2 before Phase 3: location pipeline and Firestore schema are dependencies for all feature work; getting the schema wrong is expensive to fix later
- Phase 3 establishes the primary user journey before adding the complexity of auto-detection (Phase 4)
- Phase 5 (archetype) requires real `placeCounts` data written by Phase 3's MKLocalSearch pipeline
- Phase 6 last because App Store review flows are best designed once the features they gate are fully built

### Research Flags

**Phases requiring deeper research or dedicated spikes during planning:**
- **Phase 1:** Globe rendering approach (ARView vs RealityView, iOS version decision) — must test on physical device; this is the single highest-risk unknown in the project
- **Phase 2:** iOS 16.4 background location behavior — verify exact `distanceFilter` and `desiredAccuracy` combination on current iOS version before implementing; this is a production silent-failure risk
- **Phase 4:** App Store review strategy for background location — prepare Review Notes prose and demo video before submission attempt

**Phases with standard, well-documented patterns (skip research-phase):**
- **Phase 3:** PhotoKit date-range query, HealthKit step query, MapPolyline rendering — all well-documented with official Apple samples
- **Phase 5:** Firestore Codable (now built into FirebaseFirestore directly) — standard pattern, breaking change is documented
- **Phase 6:** Permission flows — Apple guidelines are explicit; no new research needed

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | MEDIUM-HIGH | MapKit globe limitation confirmed by Apple Forums (HIGH). RealityKit as replacement is correct direction but globe country-highlight rendering on RealityKit sphere is uncharted — plan a spike. Firebase 12.x breaking changes documented in official release notes (HIGH). |
| Features | MEDIUM-HIGH | Core features well-documented from Polarsteps/Strava comparisons. Archetype system is synthesized from Bain, QVI, Foursquare taxonomy — directionally correct but specific threshold values (>35% for archetype assignment) need empirical tuning. |
| Architecture | MEDIUM-HIGH | MVVM + Clean Architecture consensus is strong. AppRouter stacked-sheet pattern has working examples (Icecubes Mastodon client, Martin's Tech Journal). Firestore denormalization patterns are standard. SwiftData + Firestore type separation is a known footgun with documented mitigation. |
| Pitfalls | HIGH | iOS 16.4 background location bug verified against iOS developer forums and Cropsly measurement blog. CLPlacemark category limitation confirmed by Apple Developer Forums. GeoJSON polygon performance confirmed by Apple Forums thread/696888. Firebase module changes confirmed by official release notes. |

**Overall confidence:** MEDIUM-HIGH

### Gaps to Address

- **Globe country-highlight rendering on RealityKit sphere:** The approach of projecting GeoJSON polygon coordinates onto a RealityKit sphere as geometry or texture overlay is architecturally described but has no off-the-shelf Swift library. This is the highest implementation-complexity unknown. Plan a standalone spike (not inside a feature sprint) to validate the polygon-to-sphere projection approach before Phase 1 is marked complete. Complexity: HIGH.

- **Archetype scoring thresholds:** The recommended thresholds (>35% for primary archetype assignment, >20 countries + high frequency for Globetrotter) are reasoned estimates from industry archetype research, not validated against real Nomad user data. These will need tuning once real trip data is available. Design the scoring system to make thresholds configurable (not hardcoded) from day one.

- **MKLocalPointsOfInterestRequest rate limits:** Apple does not publish rate limits for MKLocalSearch / MKLocalPointsOfInterestRequest. During active trip logging with continuous location updates, querying nearby POIs at high frequency could trigger silent throttling. Build a local coordinate-keyed cache (cache POI results per ~100m grid cell) to avoid re-querying the same location repeatedly.

- **Foursquare attribution requirement:** If Foursquare Places API is chosen for richer place categorization, the free tier requires visible "Powered by Foursquare" attribution wherever venue data appears. Design the place detail view with an attribution slot before committing to Foursquare. `MKLocalPointsOfInterestRequest` avoids this entirely.

- **iOS 18 migration timing:** `CLServiceSession` (iOS 18+) may be required for reliable background location delivery in future OS versions. Research suggests apps not using it may have background delivery interrupted on iOS 18+. Plan a Phase 2 investigation item to verify current CoreLocation documentation on this point before finalizing the LocationService implementation.

---

## Sources

### Primary (HIGH confidence)
- Apple Developer Forums thread/760542 — MapKit standard style does not render globe on iPhone
- Apple Developer Forums thread/719516 — No replacement for MKMapType globe view in iOS 16
- Apple Developer Documentation: CLVisit — background delivery, relaunch behavior
- Apple Developer Documentation: Handling Location Updates in Background — background mode requirements
- Apple Developer Documentation: MKPointOfInterestCategory — full category list and MKMapItem availability
- Firebase Apple SDK release notes — v11/v12 breaking changes, FirebaseFirestoreSwift module removal
- Firebase iOS Setup Documentation — Swift Package Manager, AppDelegate requirement in SwiftUI lifecycle
- WWDC 2023: Meet MapKit for SwiftUI — MapPolyline, MapCamera, iOS 17 API surface
- WWDC 2023: Discover streamlined location updates — CLLocationUpdate, CLBackgroundActivitySession
- WWDC 2025: Bring your SceneKit project to RealityKit — SceneKit soft deprecation
- Apple Energy Efficiency Guide — location best practices (archived official)
- Apple App Store Review Guidelines 5.1.1 — background location justification requirements
- Apple HealthKit Protecting User Privacy — data use restrictions, privacy policy URL requirement
- Apple Developer Forums thread/696888 — MapKit polygon performance with 100k+ points
- iOS 16.4 Background Location Changes — Cropsly measurement blog (verified against forums)
- CoreLocation modern API tips — twocentstudios.com December 2024 (CLLocationUpdate limitations)

### Secondary (MEDIUM confidence)
- Polarsteps Review 2025 (Wandrly) — competitive feature comparison
- Polarsteps Unpacked 2025 — annual recap feature precedent
- Strava Sticker Stats Spring 2025 (BikeRadar) — shareable card design reference
- Five Key Traveler Archetypes (Hospitality News Magazine / Bain & Company) — archetype taxonomy source
- Six Travel Personality Types (QVI) — archetype taxonomy cross-reference
- Foursquare Place Categories Documentation — 1,200+ category taxonomy for archetype mapping
- NomadMania Trip Statistics 2025 — qualitative vs quantitative stat preference data
- Modern iOS App Architecture 2025 (7Span) — MVVM vs Clean Architecture vs TCA comparison
- Decoupled Stacked Sheet Navigation (Martin's Tech Journal) — AppRouter pattern reference
- SwiftUI .sheet() pitfalls (Juniperphoton) — background/foreground touch event bug
- @Observable macro performance (Antoine van der Lee) — re-render optimization
- SwiftSimplify, Simplify-Swift (GitHub) — Ramer-Douglas-Peucker Swift implementations

### Tertiary (LOW confidence — verify at implementation)
- iOS 18 CLServiceSession requirement for background delivery — mentioned in FEATURES.md research; verify against current Apple docs before implementing LocationService
- MKLocalPointsOfInterestRequest rate limits — undocumented; build cache defensively

---

## Appendix: Decision Checklist for Phase 1

The following decisions must be made before Phase 1 begins. They affect implementation path and cannot be changed cheaply after work starts.

| Decision | Options | Recommendation | Impact |
|----------|---------|----------------|--------|
| iOS minimum deployment target | 17.0 vs 18.0 | 17.0 (ARView path); migrate to RealityView when 18 becomes practical | Determines globe implementation: ARView (UIViewRepresentable) vs RealityView |
| Globe rendering framework | RealityKit, SceneKit, third-party | RealityKit — SceneKit is deprecated | Core architecture of home view |
| Authentication method | Sign in with Apple only, email/password, both | Decide before Firebase Auth setup | Determines onboarding flow and App Store compliance |
| Place categorization source | MKLocalPointsOfInterestRequest, Foursquare | MKLocalPointsOfInterestRequest first; add Foursquare if 30 categories prove too coarse | Affects archetype data model and third-party dependency footprint |
| Foursquare attribution | Required if Foursquare is used | If using Foursquare, attribution slot must be in design from day one | UI design constraint |

---
*Research completed: 2026-04-03*
*Ready for roadmap: yes*
