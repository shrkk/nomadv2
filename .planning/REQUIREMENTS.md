# Requirements: Nomad

**Defined:** 2026-04-03
**Core Value:** A traveler opens Nomad after a trip and immediately sees a beautiful, shareable visual of everywhere they went that day — and over time, a growing picture of who they are as a traveler.

## v1 Requirements

### Infrastructure & Spikes

- [ ] **INFRA-01**: Globe rendering approach validated on physical device (RealityKit/ARView — MapKit does not support 3D globe on iPhone)
- [ ] **INFRA-02**: Stacked bottom-sheet navigation pattern validated (SwiftUI sheet-within-sheet behavior confirmed)
- [ ] **INFRA-03**: Firebase 12.x connected via Swift Package Manager with SwiftUI app initialization pattern
- [ ] **INFRA-04**: World-country GeoJSON dataset pre-simplified offline and bundled with app

### Authentication & Onboarding

- [ ] **AUTH-01**: User can sign up and sign in with email/password via Firebase Auth
- [ ] **AUTH-02**: User session persists across app restarts
- [ ] **AUTH-03**: User sets a unique handle during onboarding (validated against Firestore for uniqueness)
- [ ] **AUTH-04**: User grants location permissions (always-on, required for background tracking) during onboarding
- [ ] **AUTH-05**: User grants Apple Photos library access during onboarding
- [ ] **AUTH-06**: User chooses discovery scope at onboarding: "everywhere" or "away from home city only"
- [ ] **AUTH-07**: Home city geofence registered at onboarding (used for trip auto-detection)

### Globe Home View

- [ ] **GLOBE-01**: Interactive 3D globe rendered as the persistent home view (RealityKit/ARView)
- [ ] **GLOBE-02**: Visited countries highlighted with subtle glow overlay on globe surface (GeoJSON polygons projected onto sphere)
- [ ] **GLOBE-03**: Tap a highlighted country → globe animates/zooms to that region and shows trip pinpoints
- [ ] **GLOBE-04**: Trip pinpoints on globe represent logged day trips within that country
- [ ] **GLOBE-05**: Tap a pinpoint → bottom sheet slides up with city name, travel stats, and photo gallery

### Location Pipeline

- [ ] **LOC-01**: Background GPS recording using CLLocationManager with correct iOS 16.4+ accuracy and distance filter settings
- [ ] **LOC-02**: CLBackgroundActivitySession used to keep location session alive when app is backgrounded
- [ ] **LOC-03**: Route points buffered locally in SwiftData before sync to Firestore
- [ ] **LOC-04**: Ramer-Douglas-Peucker simplification applied to GPS traces (detail view: ~500pts, globe preview: ~50pts)
- [ ] **LOC-05**: CLVisit monitoring detects departure from home city and triggers trip prompt notification
- [ ] **LOC-06**: Discovery scope enforced — home city geofence suppresses prompts when "away only" mode is set

### Place Categorization

- [ ] **PLACE-01**: Each logged stop categorized using MKLocalPointsOfInterestRequest (not CLPlacemark — returns nil categories)
- [ ] **PLACE-02**: Place categories mapped to 6 scoring dimensions: Food, Culture, Nature, Nightlife, Wellness, Local/Neighborhood
- [ ] **PLACE-03**: Category results cached by coordinate key to avoid redundant API calls
- [ ] **PLACE-04**: placeCounts stored per trip in Firestore (used for archetype computation)

### Trip Logging

- [ ] **TRIP-01**: User can manually start a trip from the "+" button in the profile panel
- [ ] **TRIP-02**: App sends notification prompt when CLVisit detects departure (hybrid auto-detect)
- [ ] **TRIP-03**: After 3 dismissed auto-prompts, app switches to manual-only mode
- [ ] **TRIP-04**: Active trip indicator visible on globe home view while recording
- [ ] **TRIP-05**: Trip captures: GPS trace, visited places, place categories, steps (HealthKit), date range, city/country
- [ ] **TRIP-06**: User can stop and name a trip
- [ ] **TRIP-07**: Trip route stored with full GPS subcollection + 50-point preview array on the trip document

### Profile Panel (Bottom Sheet)

- [ ] **PANEL-01**: Bottom sheet slides up from anywhere in the app via persistent bottom handle
- [ ] **PANEL-02**: Recent trips listed chronologically (newest first) as preview cards showing the Strava-style route
- [ ] **PANEL-03**: Tap trip preview card → full trip detail panel slides up (GPS trace + named place pins, photo gallery, stats)
- [ ] **PANEL-04**: Trip detail panel can be dismissed by sliding down
- [ ] **PANEL-05**: "+" button in panel opens new trip log flow
- [ ] **PANEL-06**: Profile button in panel opens Traveler Passport

### Trip Detail View

- [ ] **DETAIL-01**: Map shows GPS trace as continuous line (Strava-style) with named place pins on top in visit order
- [ ] **DETAIL-02**: Trip stats: steps, distance, duration, places visited, most-visited category
- [ ] **DETAIL-03**: Photo gallery sourced from Apple Photos — PHAssets matched by trip date range + GPS bounding box
- [ ] **DETAIL-04**: Photos with nil location (iCloud shared albums) matched by date range as fallback
- [ ] **DETAIL-05**: City name displayed as the trip header

### Traveler Passport

- [ ] **PASS-01**: World map view with visited countries filled in (flat 2D map, not globe)
- [ ] **PASS-02**: Traveler archetype label derived from accumulated placeCounts across all trips (one of 8 archetypes)
- [ ] **PASS-03**: Archetype only shown after minimum 3 logged trips ("Still learning your style..." before threshold)
- [ ] **PASS-04**: "Travel Wrapped" stats: most-visited country, favorite activity category, total steps/distance, total countries
- [ ] **PASS-05**: Customizable profile photo
- [ ] **PASS-06**: Shareable passport card — portrait (9:16) format rendered via UIGraphicsImageRenderer, exportable to Photos/share sheet

### Traveler Archetypes

- [ ] **ARCH-01**: 8 archetypes derived from 6 place-type scoring dimensions (Food, Culture, Nature, Nightlife, Wellness, Local)
- [ ] **ARCH-02**: Archetype assigned when one dimension exceeds 35% of total score (configurable threshold)
- [ ] **ARCH-03**: Archetype shown on Passport and in trip stats

### Design System

- [ ] **DSYS-01**: Playfair Display used for all titles and subheadings
- [ ] **DSYS-02**: Inter used for all body text, buttons, and labels
- [ ] **DSYS-03**: All panels feature subtle grainy gradient flows in corners with minimalist pastel color scheme
- [ ] **DSYS-04**: All detail/profile views accessible via sliding bottom sheet panels (not full-screen navigation)
- [ ] **DSYS-05**: Design questions asked before implementing each screen/component (per user preference)

## v2 Requirements

### Friends & Social

- **SOCL-01**: User can add friends by handle
- **SOCL-02**: User can view a friend's globe (highlighted countries)
- **SOCL-03**: User can view a friend's full Traveler Passport and stats
- **SOCL-04**: Friend requests and accept/reject flow
- **SOCL-05**: Firestore social graph schema (designed in v1, built in v2)

### Annual Travel Wrapped

- **WRAP-01**: Year-end summary of top destinations, total stats, archetype evolution
- **WRAP-02**: Shareable annual wrapped card

### Enhanced Discovery

- **DISC-01**: Discover nearby travelers (opt-in)
- **DISC-02**: Popular places visited by Nomad users in a destination

## Out of Scope

| Feature | Reason |
|---------|--------|
| Android / cross-platform | Native iOS SwiftUI only — Apple API depth is core to the experience |
| Social activity feed | Friends feature is profile-viewing only, not a timeline — keeps scope clear |
| In-app chat or messaging | Not a social network, a travel journal |
| Custom mapping engine | Apple MapKit + RealityKit covers all map needs |
| Web app | Mobile native only for v1 |
| Third-party OAuth (Google, Apple Sign-In) | Email/password sufficient for v1; Add Sign in with Apple before any third-party social auth is added |
| Real-time collaborative trips | Single-user trips only in v1 |
| Paid/subscription tier | Free app, no monetization in v1 |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| INFRA-01 | Phase 1 | Pending |
| INFRA-02 | Phase 1 | Pending |
| INFRA-03 | Phase 1 | Pending |
| INFRA-04 | Phase 1 | Pending |
| GLOBE-01 | Phase 1 | Pending |
| GLOBE-02 | Phase 1 | Pending |
| GLOBE-03 | Phase 1 | Pending |
| GLOBE-04 | Phase 1 | Pending |
| GLOBE-05 | Phase 1 | Pending |
| AUTH-01 | Phase 2 | Pending |
| AUTH-02 | Phase 2 | Pending |
| AUTH-03 | Phase 2 | Pending |
| AUTH-04 | Phase 2 | Pending |
| AUTH-05 | Phase 2 | Pending |
| AUTH-06 | Phase 2 | Pending |
| AUTH-07 | Phase 2 | Pending |
| LOC-01 | Phase 2 | Pending |
| LOC-02 | Phase 2 | Pending |
| LOC-03 | Phase 2 | Pending |
| LOC-04 | Phase 2 | Pending |
| LOC-05 | Phase 2 | Pending |
| LOC-06 | Phase 2 | Pending |
| PLACE-01 | Phase 2 | Pending |
| PLACE-02 | Phase 2 | Pending |
| PLACE-03 | Phase 2 | Pending |
| PLACE-04 | Phase 2 | Pending |
| PANEL-01 | Phase 3 | Pending |
| PANEL-02 | Phase 3 | Pending |
| PANEL-03 | Phase 3 | Pending |
| PANEL-04 | Phase 3 | Pending |
| PANEL-05 | Phase 3 | Pending |
| PANEL-06 | Phase 3 | Pending |
| TRIP-01 | Phase 3 | Pending |
| TRIP-02 | Phase 3 | Pending |
| TRIP-03 | Phase 3 | Pending |
| TRIP-04 | Phase 3 | Pending |
| TRIP-05 | Phase 3 | Pending |
| TRIP-06 | Phase 3 | Pending |
| TRIP-07 | Phase 3 | Pending |
| DETAIL-01 | Phase 4 | Pending |
| DETAIL-02 | Phase 4 | Pending |
| DETAIL-03 | Phase 4 | Pending |
| DETAIL-04 | Phase 4 | Pending |
| DETAIL-05 | Phase 4 | Pending |
| PASS-01 | Phase 5 | Pending |
| PASS-02 | Phase 5 | Pending |
| PASS-03 | Phase 5 | Pending |
| PASS-04 | Phase 5 | Pending |
| PASS-05 | Phase 5 | Pending |
| PASS-06 | Phase 5 | Pending |
| ARCH-01 | Phase 5 | Pending |
| ARCH-02 | Phase 5 | Pending |
| ARCH-03 | Phase 5 | Pending |
| DSYS-01 | Phase 1 | Pending |
| DSYS-02 | Phase 1 | Pending |
| DSYS-03 | Phase 1 | Pending |
| DSYS-04 | Phase 1 | Pending |
| DSYS-05 | Phase 1 | Pending |

**Coverage:**
- v1 requirements: 54 total
- Mapped to phases: 54
- Unmapped: 0 ✓

---
*Requirements defined: 2026-04-03*
*Last updated: 2026-04-03 after initial definition*
