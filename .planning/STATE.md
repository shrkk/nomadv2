# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-03)

**Core value:** A traveler opens Nomad after a trip and immediately sees a beautiful, shareable visual of everywhere they went that day — and over time, a growing picture of who they are as a traveler.
**Current focus:** Not started — ready for Phase 1 planning

## Current Status

**Milestone:** v1 — Initial Release
**Phase:** None started
**Next action:** `/gsd:plan-phase 1`

## Roadmap Snapshot

| Phase | Name | Status |
|-------|------|--------|
| 1 | Foundation Spikes & Globe Shell | Not started |
| 2 | Data & Auth Foundation | Not started |
| 3 | Core User Journey | Not started |
| 4 | Traveler Passport & Archetype System | Not started |

## Key Decisions Made During Init

- **Globe**: MapKit cannot render a 3D globe on iPhone — must use RealityKit/ARView
- **Place categories**: CLPlacemark returns nil — use MKLocalPointsOfInterestRequest
- **Archetypes**: 8 types driven by 6 place-type dimensions (Food, Culture, Nature, Nightlife, Wellness, Local)
- **Archetype threshold**: 35% primary dimension (configurable)
- **Trip auto-detect**: CLVisit + geofence departure, 3-dismiss limit before manual-only
- **Backend**: Firebase 12.x via SPM
- **SceneKit**: Soft-deprecated WWDC 2025 — use RealityKit

## Critical Spikes for Phase 1

1. RealityKit/ARView globe rendering on physical device
2. Country GeoJSON polygon projection onto sphere surface
3. Stacked SwiftUI bottom sheet navigation validation

---
*Initialized: 2026-04-03*
