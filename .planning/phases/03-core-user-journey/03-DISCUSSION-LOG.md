# Phase 3: Core User Journey - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the discussion.

**Date:** 2026-04-06
**Phase:** 03-core-user-journey
**Mode:** discuss
**Areas discussed:** Profile panel handle, Trip card route preview, Trip start + naming flow, Active trip indicator, Photo gallery layout, Trip detail place pins

## Gray Areas Presented

| Area | Options Offered | Selection |
|------|----------------|-----------|
| Profile panel handle | Floating drag strip / Tab-bar / Icon button | Floating drag strip |
| Trip card route preview | SwiftUI Path / MapKit per card / Static thumbnail | SwiftUI Path |
| Trip naming flow | Name at end (stop→dialog) / Name at start | Name at end |
| Active trip indicator | Floating pill w/ timer+stop / Pulsing dot only / Expandable | Floating pill w/ timer+stop |
| Photo gallery layout | Horizontal strip / Grid / Count badge only | Horizontal strip |
| Place pins in detail map | Numbered (1,2,3) / Category icons + labels / Amber dots | Numbered pins |

## Corrections Made

No corrections — all recommended options confirmed.

## Prior Decisions Applied

From Phase 1:
- Amber (#E8A44A) as primary accent color — applied to route preview line, place pins, recording pill stop button
- `.panelGradient()` modifier — applied to ProfileSheet and TripDetailSheet (no change)
- AppFont scale — carried forward for all text in new components

From Phase 2:
- Firestore schema (D-12 through D-16) — all field names and paths used verbatim
- `routePreview` as 50-pt lat/lon array — confirmed as data source for SwiftUI Path drawing
- `LocationManager`, `TripService`, `VisitMonitor` all confirmed complete and ready to wire
- 3-dismiss counter explicitly deferred in VisitMonitor code with Phase 3 TODO comment — Phase 3 implements this

## Codebase Insights Used

- `ProfileSheet.swift` and `TripDetailSheet.swift` exist as stubs — Phase 3 fills them with real data
- `GlobeView.swift` uses `GlobePinpoint.StubTrip.stubTrips` — replaced with real Firestore trip fetch
- `GlobeCountryOverlay.hardcodedVisitedCodes` — replaced with `visitedCountryCodes` from user Firestore document
- `MKMapView via UIViewRepresentable` already established in `GlobeMapView` — same pattern for TripDetailSheet route map
- `LocationManager.currentTripId` already stores active trip UUID — recording pill reads this to confirm active state
