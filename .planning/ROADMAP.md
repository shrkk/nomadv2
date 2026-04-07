# ROADMAP: Nomad iOS Travel App

**Milestone:** v1 — Core Travel Logging Experience
**Defined:** 2026-04-03
**Granularity:** Coarse (4 phases, 1–3 plans each)
**Coverage:** 58 v1 requirements mapped across 4 phases

---

## Phases

- [ ] **Phase 1: Foundation Spikes & Globe Shell** — Validate the two highest-risk architectural unknowns (RealityKit globe + stacked sheet navigation), establish the GeoJSON polygon pipeline, connect Firebase, and lock in the design system. Nothing else starts until this phase proves the core architecture works on a physical device.
- [ ] **Phase 2: Data & Auth Foundation** — Build the complete location recording pipeline (background GPS, CLVisit detection, route simplification), place categorization via MKLocalSearch, Firebase Auth, and the full onboarding flow.
- [ ] **Phase 3: Core User Journey** — Assemble the primary product loop: profile panel with trip history, manual + auto trip logging UX, active recording indicator, and the full trip detail view with GPS trace, photo gallery, and HealthKit steps.
- [ ] **Phase 4: Traveler Passport & Archetype System** — Build the identity layer that gives users a reason to keep logging: the Traveler Passport with world map and lifetime stats, the 8-archetype scoring engine, and the shareable passport and trip card export.

---

## Phase Details

### Phase 1: Foundation Spikes & Globe Shell

**Goal:** Prove the RealityKit globe renders visited-country polygons on a physical device without stutter, prove the stacked bottom-sheet navigation pattern works reliably, establish the bundled GeoJSON pipeline, connect Firebase, and ship the Playfair Display + Inter design system as reusable components — so every subsequent phase builds on proven ground.

**Depends on:** Nothing (first phase)

**Requirements:** INFRA-01, INFRA-02, INFRA-03, INFRA-04, GLOBE-01, GLOBE-02, GLOBE-03, GLOBE-04, GLOBE-05, DSYS-01, DSYS-02, DSYS-03, DSYS-04, DSYS-05

**Success Criteria** (what must be TRUE when this phase ends):
1. A RealityKit/ARView globe renders on a physical iPhone 17+, rotates freely under touch input, and shows filled country-polygon overlays for a hardcoded set of five visited countries — no stutter during pan or zoom.
2. Tapping a highlighted country animates the camera to that region and renders hardcoded trip pinpoints; tapping a pinpoint causes the profile bottom sheet to slide up with stub content.
3. From inside the profile bottom sheet, tapping a trip card causes a second trip-detail bottom sheet to slide up; dismissing the detail sheet (slide down) leaves the profile sheet visible; dismissing the profile sheet returns to the globe. Both sheets dismiss cleanly with no unexpected cascades.
4. The GeoJSON world-country dataset is bundled offline, pre-simplified to under 100K total polygon points, parsed off the main thread at launch, and loads in under two seconds on device.
5. Firebase Auth and Firestore are connected; a stub user document can be written and read back; the app initializes Firebase via AppDelegate adaptor without crashing.
6. Playfair Display (titles/subheadings) and Inter (body/buttons/labels) are loaded and applied via a shared `AppFont` type; at least one title and one body label are visible on the globe home view using these fonts.

**Plans:** 4 plans

Plans:
- [x] 01-01-PLAN.md — Design system tokens (AppFont, AppColors, PanelGradient) + Firebase setup
- [x] 01-02-PLAN.md — GeoJSON pipeline (download, simplify, bundle, parse)
- [x] 01-03-PLAN.md — Globe rendering spike (RealityKit sphere + country overlay texture)
- [ ] 01-04-PLAN.md — Globe interactions + stacked sheets (tap, animate, pinpoints, nested sheets)

**UI hint**: yes

---

### Phase 2: Data & Auth Foundation

**Goal:** Deliver a complete, device-tested data pipeline — background GPS recording that survives a locked screen for 10+ minutes, CLVisit-based trip detection, Ramer-Douglas-Peucker route simplification, MKLocalSearch place categorization, and the full Firebase Auth + onboarding flow — so that Phase 3's UI has real, correctly-structured data to display.

**Depends on:** Phase 1

**Requirements:** AUTH-01, AUTH-02, AUTH-03, AUTH-04, AUTH-05, AUTH-06, AUTH-07, LOC-01, LOC-02, LOC-03, LOC-04, LOC-05, LOC-06, PLACE-01, PLACE-02, PLACE-03, PLACE-04

**Success Criteria** (what must be TRUE when this phase ends):
1. A new user can complete onboarding: create an account with email/password, set a unique handle (validated against Firestore for uniqueness), grant always-on location permission, grant Photos library access, and choose a discovery scope — all in a single linear flow.
2. With the app backgrounded and the screen locked for 10 minutes on a physical device, background GPS recording continues without interruption; route points accumulate in SwiftData and are later written to Firestore's `routePoints` subcollection.
3. CLVisit monitoring detects departure from the registered home city geofence and sends a local notification prompt; when discovery scope is set to "away from home city only," no prompt fires while the device stays within the geofence.
4. A completed trip's GPS trace is processed by the route simplifier — raw points → ~200-500pt simplified route → ~50pt preview array — and the trip document is written to Firestore with `routePreview`, `placeCounts`, and `visitedCountryCodes` denormalized correctly.
5. Each visited stop is categorized using MKLocalPointsOfInterestRequest (not CLPlacemark); category results are cached by coordinate key; `placeCounts` on the trip document reflects the correct breakdown across the 6 scoring dimensions (Food, Culture, Nature, Nightlife, Wellness, Local).
6. Session persists across app restarts: a returning user lands directly on the globe without going through onboarding again.

**Plans:** 4 plans

Plans:
- [x] 02-01-PLAN.md — AuthManager, UserService, data models, Firestore schema, security rules
- [x] 02-02-PLAN.md — Full onboarding flow (7 screens: Welcome through Home City Confirm)
- [x] 02-03-PLAN.md — Location pipeline (background GPS, CLVisit monitor, RDP simplification)
- [x] 02-04-PLAN.md — Place categorization service + trip finalization pipeline

**UI hint**: yes

---

### Phase 3: Core User Journey

**Goal:** Assemble the full product loop that a user experiences on every trip: the persistent profile panel shows real trip history, the user can start a trip manually or accept an auto-detect prompt, an active recording indicator shows while logging, and tapping any trip opens the detail view with a Strava-style route map, matched photo gallery, and step count — all reading from the data pipeline built in Phase 2.

**Depends on:** Phase 2

**Requirements:** PANEL-01, PANEL-02, PANEL-03, PANEL-04, PANEL-05, PANEL-06, TRIP-01, TRIP-02, TRIP-03, TRIP-04, TRIP-05, TRIP-06, TRIP-07, DETAIL-01, DETAIL-02, DETAIL-03, DETAIL-04, DETAIL-05

**Success Criteria** (what must be TRUE when this phase ends):
1. The profile bottom sheet is accessible from anywhere in the app via a persistent bottom handle; it lists real trips from Firestore/SwiftData cache in reverse chronological order as preview cards showing the simplified route shape.
2. Tapping the "+" button in the panel starts a new trip log; the globe home view shows an active-trip indicator while recording is in progress; the user can stop and name the trip, triggering the route-save and Firestore-write flow.
3. After three dismissed auto-detect prompts, the app silently switches to manual-only mode and stops sending CLVisit-triggered notifications.
4. Tapping a trip preview card opens the trip detail panel, which shows: a MapKit map with the full GPS trace as a continuous polyline and named place pins at key stops in visit order; trip stats (steps, distance, duration, places visited, most-visited category); and the city name as the panel header.
5. The photo gallery in trip detail displays PHAssets matched by trip date range and GPS bounding box; photos without location metadata (iCloud shared albums) are included via date-range-only fallback; thumbnails scroll smoothly without main-thread blocking.
6. The globe home view highlights visited countries using `visitedCountryCodes` from the user document, and renders trip pinpoints for each logged trip; tapping a pinpoint slides up the profile panel scrolled to that trip.
7. The profile panel has a Profile button that opens the Traveler Passport (stub view acceptable in this phase — full implementation is Phase 4).

**Plans:** 4 plans

Plans:
- [x] 03-01-PLAN.md — TripDocument model, GlobeViewModel Firestore fetch, environment injection
- [x] 03-02-PLAN.md — Drag strip, ProfileSheet with route preview cards, Passport stub
- [x] 03-03-PLAN.md — Recording pill, trip start/stop/name flow, VisitMonitor dismiss counter
- [x] 03-04-PLAN.md — TripDetailSheet with MapKit route map, stats row, photo gallery

**UI hint**: yes

---

### Phase 03.1: Country Detail View (INSERTED)

**Goal:** When a user taps a highlighted country on the globe, a bottom sheet slides up showing: a country header, a horizontally scrollable city strip (cities grouped by proximity), a full-width per-city photo carousel with a temperature notch, location subheadings, a stats pill (logs / km / photos), and trip log entries for the selected city.

**Depends on:** Phase 3

**Success Criteria:**
1. Tapping a visited country on the globe presents the Country Detail sheet animating up from the bottom panel.
2. The sheet header shows the country name top-left with a back/dismiss control.
3. A horizontal strip shows thumbnail cards for each visited city in the country, grouped by geographic proximity (same clustering logic as trip route grouping).
4. Selecting a city card scrolls the main carousel to that city's photos.
5. The full-width photo carousel shows the user's photos for the selected city; a pill notch centered at the top displays the temperature (current via WeatherKit or historical from trip data).
6. Below the photo card: location name in a large subheading, city + country in a smaller lighter subheading.
7. A stats pill row shows: number of trip logs, total km traveled, and total photos taken in that city.
8. Below the stats pill, trip log entries for that city are listed in chronological order.

**Plans:** TBD

### Phase 4: Traveler Passport & Archetype System

**Goal:** Build the identity and shareability layer: the Traveler Passport view with a flat world map of visited countries and lifetime stats, the 8-archetype scoring engine reading from denormalized `placeCounts`, the archetype label with minimum-trip threshold, and the shareable portrait-format passport card and trip card exportable to Photos or the share sheet.

**Depends on:** Phase 3

**Requirements:** PASS-01, PASS-02, PASS-03, PASS-04, PASS-05, PASS-06, ARCH-01, ARCH-02, ARCH-03

**Success Criteria** (what must be TRUE when this phase ends):
1. The Traveler Passport opens from the profile panel and displays a flat 2D world map with all visited countries filled in, sourced from the same `visitedCountryCodes` used by the globe.
2. The "Travel Wrapped" stats block shows: most-visited country, favorite activity category, total steps, total distance, and total countries visited — all computed from Firestore trip data without requiring a server function.
3. After fewer than 3 logged trips, the archetype section displays "Still learning your style..." instead of an archetype label; after 3 or more trips, one of 8 archetypes is displayed, computed from the weighted `placeCounts` across all trips using the 35%-threshold scoring rule.
4. Archetype scoring thresholds are not hardcoded — they are read from a configurable constant (so tuning does not require a code change).
5. The user can set a custom profile photo on their Passport card.
6. Tapping "Share" on the Passport renders a 9:16 portrait card via UIGraphicsImageRenderer, including the archetype label, world map thumbnail, key stats, and user handle — the exported image is saveable to Photos and shareable via the system share sheet without crashing on any tested device.

**Plans:** TBD

**UI hint**: yes

---

## Progress Table

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation Spikes & Globe Shell | 0/4 | Planned | - |
| 2. Data & Auth Foundation | 0/4 | Planned | - |
| 3. Core User Journey | 0/4 | Planned | - |
| 4. Traveler Passport & Archetype System | 0/2 | Not started | - |

---

## Traceability

All 58 v1 requirement IDs mapped to exactly one phase. No unmapped requirements.

| Requirement | Description (brief) | Phase | Status |
|-------------|---------------------|-------|--------|
| INFRA-01 | Globe rendering validated on physical device (RealityKit/ARView) | Phase 1 | Pending |
| INFRA-02 | Stacked bottom-sheet navigation pattern validated | Phase 1 | Pending |
| INFRA-03 | Firebase 12.x connected via SPM with SwiftUI init | Phase 1 | Pending |
| INFRA-04 | World-country GeoJSON pre-simplified and bundled | Phase 1 | Pending |
| GLOBE-01 | Interactive 3D globe as persistent home view | Phase 1 | Pending |
| GLOBE-02 | Visited countries highlighted with GeoJSON polygon overlays | Phase 1 | Pending |
| GLOBE-03 | Tap country → camera animates to region, shows trip pinpoints | Phase 1 | Pending |
| GLOBE-04 | Trip pinpoints on globe represent logged day trips | Phase 1 | Pending |
| GLOBE-05 | Tap pinpoint → bottom sheet with city name, stats, photo gallery | Phase 1 | Pending |
| DSYS-01 | Playfair Display for all titles and subheadings | Phase 1 | Pending |
| DSYS-02 | Inter for all body text, buttons, labels | Phase 1 | Pending |
| DSYS-03 | Grainy gradient panels with minimalist pastel color scheme | Phase 1 | Pending |
| DSYS-04 | All detail/profile views via sliding bottom sheet panels | Phase 1 | Pending |
| DSYS-05 | Design questions asked before each screen/component | Phase 1 | Pending |
| AUTH-01 | Sign up and sign in with email/password via Firebase Auth | Phase 2 | Pending |
| AUTH-02 | Session persists across app restarts | Phase 2 | Pending |
| AUTH-03 | User sets unique handle validated against Firestore | Phase 2 | Pending |
| AUTH-04 | Always-on location permission granted during onboarding | Phase 2 | Pending |
| AUTH-05 | Photos library access granted during onboarding | Phase 2 | Pending |
| AUTH-06 | Discovery scope chosen at onboarding (everywhere vs away-only) | Phase 2 | Pending |
| AUTH-07 | Home city geofence registered at onboarding | Phase 2 | Pending |
| LOC-01 | Background GPS with correct iOS 16.4+ accuracy/filter settings | Phase 2 | Pending |
| LOC-02 | CLBackgroundActivitySession keeps location alive when backgrounded | Phase 2 | Pending |
| LOC-03 | Route points buffered in SwiftData before Firestore sync | Phase 2 | Pending |
| LOC-04 | Ramer-Douglas-Peucker simplification on GPS traces | Phase 2 | Pending |
| LOC-05 | CLVisit monitoring detects home city departure, triggers prompt | Phase 2 | Pending |
| LOC-06 | Discovery scope enforced — home city geofence suppresses prompts | Phase 2 | Pending |
| PLACE-01 | Each stop categorized via MKLocalPointsOfInterestRequest | Phase 2 | Pending |
| PLACE-02 | Categories mapped to 6 scoring dimensions | Phase 2 | Pending |
| PLACE-03 | Category results cached by coordinate key | Phase 2 | Pending |
| PLACE-04 | placeCounts stored per trip in Firestore | Phase 2 | Pending |
| PANEL-01 | Bottom sheet accessible from anywhere via persistent handle | Phase 3 | Pending |
| PANEL-02 | Recent trips listed chronologically as preview route cards | Phase 3 | Pending |
| PANEL-03 | Tap trip card → full trip detail panel slides up | Phase 3 | Pending |
| PANEL-04 | Trip detail panel dismissed by sliding down | Phase 3 | Pending |
| PANEL-05 | "+" button in panel opens new trip log flow | Phase 3 | Pending |
| PANEL-06 | Profile button in panel opens Traveler Passport | Phase 3 | Pending |
| TRIP-01 | User can manually start a trip from the "+" button | Phase 3 | Pending |
| TRIP-02 | App sends notification prompt when CLVisit detects departure | Phase 3 | Pending |
| TRIP-03 | After 3 dismissed prompts, switches to manual-only mode | Phase 3 | Pending |
| TRIP-04 | Active trip indicator visible on globe home view | Phase 3 | Pending |
| TRIP-05 | Trip captures GPS trace, places, categories, steps, date, city | Phase 3 | Pending |
| TRIP-06 | User can stop and name a trip | Phase 3 | Pending |
| TRIP-07 | Trip stored with full GPS subcollection + 50-point preview array | Phase 3 | Pending |
| DETAIL-01 | Map shows GPS trace polyline + named place pins in visit order | Phase 3 | Pending |
| DETAIL-02 | Trip stats: steps, distance, duration, places, top category | Phase 3 | Pending |
| DETAIL-03 | Photo gallery from Photos — PHAssets matched by date + bounding box | Phase 3 | Pending |
| DETAIL-04 | Nil-location photos matched by date range as fallback | Phase 3 | Pending |
| DETAIL-05 | City name displayed as trip header | Phase 3 | Pending |
| PASS-01 | World map view with visited countries filled in (flat 2D) | Phase 4 | Pending |
| PASS-02 | Traveler archetype label derived from accumulated placeCounts | Phase 4 | Pending |
| PASS-03 | Archetype shown only after minimum 3 logged trips | Phase 4 | Pending |
| PASS-04 | "Travel Wrapped" stats: country, category, steps, distance, total countries | Phase 4 | Pending |
| PASS-05 | Customizable profile photo | Phase 4 | Pending |
| PASS-06 | Shareable 9:16 passport card via UIGraphicsImageRenderer | Phase 4 | Pending |
| ARCH-01 | 8 archetypes from 6 place-type scoring dimensions | Phase 4 | Pending |
| ARCH-02 | Archetype assigned when one dimension exceeds 35% threshold (configurable) | Phase 4 | Pending |
| ARCH-03 | Archetype shown on Passport and in trip stats | Phase 4 | Pending |

**Coverage:**
- v1 requirements in REQUIREMENTS.md: 58 (4 INFRA + 7 AUTH + 5 GLOBE + 6 LOC + 4 PLACE + 7 TRIP + 6 PANEL + 5 DETAIL + 6 PASS + 3 ARCH + 5 DSYS)
- Mapped to phases: 58
- Unmapped: 0

**Note:** REQUIREMENTS.md header states 54 requirements; the actual defined requirement IDs total 58. The traceability above accounts for all 58 IDs present in the file.

---

## Phase Ordering Rationale

**Phase 1 before everything:** The globe rendering approach (MapKit confirmed inadequate; RealityKit/ARView unproven on device) and the stacked sheet pattern (SwiftUI one-slot-per-view limit requires nested placement) are both unvalidated architectural bets. If either fails, it reshapes the entire app. No feature work starts until both are proven on hardware. The GeoJSON polygon pipeline and design system tokens are also established here because every subsequent UI phase depends on them.

**Phase 2 before Phase 3:** Location data is the raw material for every user-visible feature. The iOS 16.4+ background GPS bug, CLVisit detection, the RDP simplification pipeline, and the Firestore schema with denormalized `routePreview`, `placeCounts`, and `visitedCountryCodes` must all be finalized before the UI is built on top. Changing the Firestore schema after Phase 3 is expensive.

**Phase 3 after Phase 2:** The core user journey (panel -> trip -> detail) is straightforward to build once the data pipeline is proven. Photo matching, HealthKit steps, and trip logging UX all have well-documented Apple patterns. This phase builds UI on a solid foundation rather than assuming the pipeline works.

**Phase 4 last:** The archetype engine reads from `placeCounts` written by the Phase 2 pipeline and accumulated across trips logged in Phase 3. Passport stats require real trip data to validate scoring thresholds. Shareable card export is the final feature to polish — it benefits from the design system being fully applied in prior phases.

---

## Critical Risks by Phase

| Phase | Risk | Severity | Mitigation |
|-------|------|----------|------------|
| 1 | RealityKit country polygon overlay on sphere — no off-the-shelf solution | HIGH | Dedicated spike in Phase 1, Plan 3; texture-paint approach validated in research |
| 1 | Stacked sheet second slot — silent failure if second `.sheet` is a sibling not nested inside first | HIGH | Nested sheet pattern validated in Phase 1, Plan 4 |
| 1 | GeoJSON polygon count (195 countries, potentially 100K+ points) — MapKit lockup | HIGH | Pre-simplify offline with mapshaper before bundling; parse off main thread |
| 2 | Background location silent suspension on iOS 16.4+ with wrong distanceFilter | HIGH | Test on physical device with screen locked 10+ minutes before declaring Phase 2 complete |
| 2 | MKLocalPointsOfInterestRequest undocumented rate limits | MEDIUM | Coordinate-keyed cache (per ~100m grid cell) to avoid re-querying same location |
| 3 | PHAsset.location nil for iCloud shared photos | LOW | Date-range fallback implemented from the start (DETAIL-04) |
| 3 | MapKit annotation clustering needed at scale (> 10 pins per region) | MEDIUM | Use MKClusterAnnotation for globe pin layer |
| 4 | Archetype thresholds are estimates — real data may not distribute as expected | MEDIUM | Make thresholds configurable from day one (ARCH-02); plan internal review with sample data |

---
*Roadmap defined: 2026-04-03*
*Phase 1 planned: 2026-04-04*
*Phase 2 planned: 2026-04-05*
*Phase 3 planned: 2026-04-06*
*Granularity: coarse*
