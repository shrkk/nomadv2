# Nomad

## What This Is

Nomad is a native iOS travel app (SwiftUI) that uses location data to help people understand how they travel — what types of places they frequent, what kind of traveler they are — and lets them share a beautiful, Strava-style visual record of their journeys. The core experience is an interactive globe where visited countries glow and drill down to mapped day trips, photo galleries, and travel statistics.

## Core Value

A traveler opens Nomad after a trip and immediately sees a beautiful, shareable visual of everywhere they went that day — and over time, a growing picture of who they are as a traveler.

## Requirements

### Validated

(None yet — ship to validate)

### Active

**Globe Home View**
- [ ] Interactive 3D globe using Apple MapKit — visited countries highlighted with subtle glow overlay
- [ ] Tap country → zoom to region, show pinpoints for logged day trips
- [ ] Tap pinpoint → slide-up panel: city name, travel stats, scrollable photo gallery (from Apple Photos)
- [ ] Globe persists as the base view across the app

**Trip Logging**
- [ ] Hybrid logging: user can manually start a trip OR app detects travel and prompts via notification
- [ ] Onboarding setting: track only when away from home city, or everywhere (user chooses)
- [ ] Capture: visited places, place types/categories, steps, route
- [ ] Route visualization: GPS trace as base + named pins at key stops (Strava-style, both layers)
- [ ] Place type data feeds into traveler archetype/discovery profile

**Profile Panel (Bottom Sheet)**
- [ ] Slides up from bottom — accessible from anywhere in the app
- [ ] Recent trips listed chronologically (newest first) as preview cards showing visual route
- [ ] Tap trip card → full trip detail panel slides up (can slide down to minimize)
- [ ] "+" button to manually start a new trip log
- [ ] Profile button → opens Traveler Passport

**Traveler Passport**
- [ ] World map view with visited countries filled in
- [ ] "Travel Wrapped" stats: countries with most time, favorite activity types, total steps/distance
- [ ] Traveler archetype label derived from place-type patterns (defined during planning)
- [ ] Customizable profile photo and profile card
- [ ] Designed as a shareable card format

**Onboarding**
- [ ] Set unique user handle
- [ ] Request location permissions (always-on for background tracking)
- [ ] Request Apple Photos library access
- [ ] Choose discovery scope: home city included or away-only

**Design System**
- [ ] Primary font: Playfair Display (titles, subheadings)
- [ ] Secondary font: Inter (body text, buttons, labels)
- [ ] Panels: subtle grainy gradient flows in corners, minimalist pastel color scheme
- [ ] All profile/detail elements accessible via bottom sheet panels

**Friends (v2)**
- [ ] Add friends by handle
- [ ] View friends' globes (highlighted countries)
- [ ] View friends' full Traveler Passports

### Out of Scope

- Android / cross-platform — native iOS SwiftUI only for v1
- Custom mapping engine — using Apple MapKit throughout
- Activity feed / social timeline — friends feature is profile-viewing only (not a feed), v2+
- Web app — mobile native only

## Context

- **Platform**: Native iOS, SwiftUI. Deep integration with Apple ecosystem is a design priority: MapKit for globe/maps, HealthKit for steps, Photos framework for gallery import.
- **Backend**: Firebase (Auth + Firestore + Storage). Handles user accounts, trip data persistence, social graph for friends feature.
- **Trip detection**: Hybrid model — user can manually initiate OR app uses location/movement signals to detect travel and sends a notification prompt. Background location access required.
- **Discovery scope**: Set at onboarding — user decides whether home city counts as a "travel" destination. This affects what triggers logging prompts.
- **Route visualization**: Both a continuous GPS trace line AND named place pins on top, in visit order. Same aesthetic as Strava activity maps.
- **Traveler archetypes**: To be defined during planning — derived from the types of places the user frequents (e.g., foodie, culture seeker, adventurer, nightlife explorer). Emergent from place-type data over time.
- **Design interaction pattern**: All detail views use sliding bottom sheets stacked on each other (slide down to dismiss). The globe is always the persistent backdrop.

## Constraints

- **Tech Stack**: SwiftUI + MapKit + Firebase — no React Native, no custom maps
- **Apple APIs**: HealthKit (steps), Photos framework (gallery), CoreLocation (GPS trace + background location), MapKit (globe + route maps)
- **Design**: Playfair Display + Inter font pairing; grainy pastel gradient panels — must be consistent across all screens
- **Design Process**: User wants detailed design questions before implementing any feature or UI component — do not make visual assumptions

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Native iOS (SwiftUI) over React Native | Deepest MapKit, HealthKit, Photos integration; design fidelity matters | — Pending |
| Firebase backend | Fast to set up, scales for social features, good iOS SDK | — Pending |
| Hybrid trip logging (manual + auto-detect) | Gives user control while reducing friction of remembering to log | — Pending |
| Home city tracking: user chooses at onboarding | Some users want everything tracked; others want pure travel-only | — Pending |
| Friends feature deferred to v2 | Core solo experience must be excellent before social layer | — Pending |
| Traveler archetypes defined during planning | Need place-type taxonomy before designing the system | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd:transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd:complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-04-03 after initialization*
