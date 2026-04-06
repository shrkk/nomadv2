---
phase: 03-core-user-journey
plan: "04"
subsystem: trip-detail
tags: [mapkit, polyline, annotations, geocoder, photos-framework, phimagemanager, trip-detail]
dependency_graph:
  requires: [03-02, 03-01]
  provides: [TripRouteMapView, PhotoGalleryStrip, TripDetailSheet-v3]
  affects: [ProfileSheet (nested TripDetailSheet), all trip card taps]
tech_stack:
  added: [MapKit (MKPolyline, MKAnnotationView, UIGraphicsImageRenderer), Photos (PHAsset, PHImageManager), CoreLocation (CLGeocoder)]
  patterns: [UIViewRepresentable coordinator with overlaysAdded guard, resumed-flag CheckedContinuation for PHImageManager, lazy geocoding with session cache]
key_files:
  created:
    - Nomad/Components/TripRouteMapView.swift
    - Nomad/Components/PhotoGalleryStrip.swift
  modified:
    - Nomad/Sheets/TripDetailSheet.swift
    - Nomad.xcodeproj/project.pbxproj
decisions:
  - "TripRouteMapContainer wraps TripRouteMapView to handle loading/empty states outside the UIViewRepresentable — keeps coordinator logic clean"
  - "visitedPlaces derived by sampling every ~20th routeCoordinate (matching TripService.sampleStopCoordinates pattern) — no separate Firestore fetch needed"
  - "overlaysAdded guard in Coordinator prevents duplicate polyline/annotation on SwiftUI re-render passes"
  - "centerOffset CGPoint(x:0, y:-size/2) on NumberedAnnotation view centers pin circle on coordinate"
  - "computeBoundingBox adds 0.01-degree (~1km) padding to GPS bounds to catch photos taken near trip route"
  - "TripDetailSheet uses ScrollView wrapper to allow photo strip and stats to scroll on small screens"
metrics:
  duration: "~25 min"
  completed: "2026-04-06"
  tasks_completed: 2
  files_changed: 4
---

# Phase 3 Plan 04: Trip Detail View Summary

MapKit route map with amber GPS polyline and numbered amber circle pins, 5-cell stats row with steps/distance/duration/places/top-category, and PHAsset photo gallery strip matched by date range and GPS bounding box with nil-location fallback.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create TripRouteMapView and rebuild TripDetailSheet with map and stats | bcb3f44 | Nomad/Components/TripRouteMapView.swift, Nomad/Sheets/TripDetailSheet.swift, Nomad.xcodeproj/project.pbxproj |
| 2 | Create PhotoGalleryStrip and integrate into TripDetailSheet | 53c399d | Nomad/Components/PhotoGalleryStrip.swift |

## What Was Built

**TripRouteMapView** (`Nomad/Components/TripRouteMapView.swift`): `UIViewRepresentable` wrapping `MKMapView`. Non-interactive (scroll/zoom/rotate/pitch disabled). `pointOfInterestFilter = .excludingAll` suppresses POI noise. Polyline rendered as amber 3pt stroke via `MKPolylineRenderer`. `NumberedAnnotation` (subclass of `MKPointAnnotation` with `index: Int`) drawn as 24pt amber circle with white index number via `UIGraphicsImageRenderer`. Pin tap triggers lazy `CLGeocoder` reverse-geocode with session cache (T-03-12 — only one geocode at a time, cached per session). Auto-fit via `setVisibleMapRect(_:edgePadding:animated:)` with 24pt padding. `overlaysAdded` guard prevents duplicate overlay/annotation on SwiftUI re-renders. `TripRouteMapContainer` wraps in 240pt `RoundedRectangle(cornerRadius: 12)` frame with loading `ProgressView`.

**TripDetailSheet rebuilt** (`Nomad/Sheets/TripDetailSheet.swift`): Full rebuild replacing stub layout. Accepts `TripDocument`. Header shows `trip.cityName` in `AppFont.title()` with `globeBackground` foreground (DETAIL-05). Date formatted as "Month D - D, YYYY" or cross-month "Month D - Month D, YYYY". Route points fetched from `FirestoreSchema.routePointsCollection` ordered by timestamp, scoped to `Auth.auth().currentUser?.uid` (T-03-13). `visitedPlaces` sampled from route at every ~20th point for numbered pins. Stats row (DETAIL-02): HStack with 5 cells — steps (decimal formatted), distance (km), duration (Xh Xm), places count, top category (SF Symbol + name from category mapping table). `warmCard` background, 12pt corner radius. Error state shows "Could not load route" caption. `PhotoGalleryStrip` integrated below stats with 24pt top padding. `computeBoundingBox` helper adds 0.01-degree padding to route bounds.

**PhotoGalleryStrip** (`Nomad/Components/PhotoGalleryStrip.swift`): Checks `PHPhotoLibrary.authorizationStatus` before any fetch (T-03-10). Requests authorization if `notDetermined`. `PHFetchOptions` predicate filters by `creationDate >= startDate AND creationDate <= endDate`. Two-pass matching: assets with GPS location filtered against bounding box; assets with nil location included via date-range fallback (DETAIL-04). Thumbnails loaded via `PHImageManager.requestImage` with `.fastFormat` delivery on background thread. `resumed-flag` pattern inside `withCheckedContinuation` ensures continuation fires exactly once (PHImageManager delivers degraded frame before final). Cap at 50 thumbnails. 80x80pt thumbnails, 8pt corner radius, `LazyHStack` in horizontal `ScrollView`. Permission denied state with Settings deep-link. Empty state "No photos for this trip." per UI-SPEC copy.

## Deviations from Plan

None — plan executed exactly as written. All architecture, component structure, and behavior implemented per task specifications.

## Known Stubs

None — all DETAIL-01 through DETAIL-05 requirements are fully implemented with live data.

## Threat Surface

**T-03-10 (Photos library read):** `PHPhotoLibrary.authorizationStatus` checked before any fetch. Photos accessed only within trip date/location range. No photo data sent to server.

**T-03-11 (CLGeocoder):** Accepted per threat register. Standard iOS behavior; user consented via location permission; coordinates are user's own trip data.

**T-03-12 (CLGeocoder rate limiting):** Mitigated. Geocode triggered only on pin tap (not all pins on load). Results cached in `Coordinator.geocodeCache` dictionary for session lifetime. Only one geocode in flight at a time via `isGeocoding` guard.

**T-03-13 (Firestore routePoints read):** Mitigated. Read scoped via `Auth.auth().currentUser?.uid`; Firestore rules enforce `request.auth.uid == uid`.

## Self-Check: PASSED

- `Nomad/Components/TripRouteMapView.swift` — FOUND
- `Nomad/Components/PhotoGalleryStrip.swift` — FOUND
- `Nomad/Sheets/TripDetailSheet.swift` (TripRouteMapView embedded, stats row, PhotoGalleryStrip) — FOUND
- `Nomad.xcodeproj/project.pbxproj` (TR, PG entries in PBXBuildFile, PBXFileReference, PBXGroup, PBXSourcesBuildPhase) — FOUND
- Commit bcb3f44 — FOUND
- Commit 53c399d — FOUND
- Build: SUCCEEDED
