# Phase 2: Data & Auth Foundation - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-04-05
**Phase:** 02-data-auth-foundation
**Mode:** discuss
**Areas analyzed:** Onboarding screens, Home city setup, Auth routing + session state, Firestore schema

## Assumptions (from prior context)

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Design system (AppFont, AppColors, panelGradient) is locked and inherited by all Phase 2 screens | Confident | Phase 1 CONTEXT.md D-01 through D-08; code in Nomad/DesignSystem/ |
| Firebase 12.x already connected via SPM; AppDelegate pattern established | Confident | AppDelegate.swift, FirebaseService.swift, STATE.md |
| Bottom sheet pattern validated (INFRA-02) | Confident | ProfileSheet.swift nested sheet implementation |
| GlobeView is the authenticated home | Confident | NomadApp.swift routes directly to GlobeView |
| MKLocalPointsOfInterestRequest (not CLPlacemark) for place categories | Confident | STATE.md Key Decisions; REQUIREMENTS.md PLACE-01 |

## Questions Asked and Answers

### Onboarding flow structure
- **Asked:** Full-screen paged vs scrollable vs bottom sheet over globe
- **Answer:** Full-screen pages with progress dots

### Welcome screen
- **Asked:** Minimal signup form vs brief value pitch vs separate welcome screen
- **Answer:** Separate welcome screen first (globe + tagline + Get started CTA)

### Welcome screen content
- **Asked:** Globe + tagline + CTA vs app name only vs animated globe
- **Answer:** Globe + tagline + Get started CTA

### Handle validation
- **Asked:** Live debounced check vs on submit only
- **Answer:** Live, debounced (500ms) with inline feedback

### Permissions UX
- **Asked:** Pre-prompt + native dialog vs native dialog only vs combined pre-prompt
- **Answer:** Pre-prompt explanation screen then native dialog (per permission)

### Discovery scope presentation
- **Asked:** Large tappable cards vs toggle vs segmented control
- **Answer:** Two large tappable option cards

### Home city detection
- **Asked:** Auto-detect + confirm vs text search vs auto-detect silently vs map picker
- **Answer:** Auto-detect from current location + confirm

### Geofence radius
- **Asked:** 50km vs 25km vs user-adjustable
- **Answer:** 50km fixed

### Auth state management
- **Asked:** @Observable AuthManager vs @AppStorage vs inline Firebase listener
- **Answer:** @Observable AuthManager singleton with Firebase Auth listener

### Launch transition
- **Asked:** Direct to globe vs brief splash vs skeleton state
- **Answer:** Globe appears directly, no splash

### Trip Firestore location
- **Asked:** users/{uid}/trips subcollection vs top-level trips vs both
- **Answer:** users/{uid}/trips/{tripId} subcollection

### RoutePoints storage
- **Asked:** Subcollection + 50pt preview vs full array on doc vs Firebase Storage
- **Answer:** Subcollection + 50pt preview array denormalized on trip doc

### Denormalized trip fields
- **Asked:** Which fields to denormalize (multiselect)
- **Answer:** routePreview, visitedCountryCodes, placeCounts, cityName + startDate + endDate

## Corrections Made

No corrections — all recommended options were accepted.

## External Research

None required — codebase and REQUIREMENTS.md provided sufficient context for all decisions.
